# Baseline Traffic Comparison

**Date:** 2026-03-25
**Status:** Proposed
**Branch:** feat/mapbox-premium

## Problem

The app shows "green / good to go" when traffic isn't actually good. This happens because:

1. When Mapbox segment congestion data is available, mood is determined purely by the ratio of congested segments — it ignores overall duration entirely. A route can be significantly slower than its best-case time while having <10% heavy segments, and still show green.
2. The existing `normalTravelTime` baseline comes from Mapbox's `duration_typical`, which represents average traffic — not the best-case no-traffic time. Comparing against "typical" makes everything look close to normal, even when traffic is meaningfully worse than ideal.

## Solution

Replace the dual mood code paths with a unified mood engine that compares current travel time against a user-chosen baseline (either no-traffic best case or typical traffic). Establish the no-traffic baseline via a one-time fetch using Mapbox's non-traffic `driving` profile or a MapKit estimate.

## Design

### 1. Baseline Data Model

**New fields in `SettingsStore`:**

| Field | Type | Default | Purpose |
|---|---|---|---|
| `baselineToWorkTime` | `TimeInterval?` | `nil` | Persisted no-traffic duration, home → work |
| `baselineToHomeTime` | `TimeInterval?` | `nil` | Persisted no-traffic duration, work → home |
| `baselineCompareMode` | `BaselineCompareMode` (enum) | `.bestCase` | `.bestCase` or `.typical` — persisted via `rawValue` like `MapsApp` |
| `useMapboxBaseline` | `Bool` | `true` | When false, uses MapKit even if Mapbox key exists |
| `baselineFetchedAt` | `Date?` | `nil` | Timestamp for display ("Baseline set on Mar 25") |

**Existing fields unchanged:**

- `Route.normalTravelTime` continues to hold Mapbox `duration_typical` (used when compare mode is "typical")
- `Route.travelTime` continues to hold current with-traffic duration

**Baseline selection logic:**

```
if settings.baselineCompareMode == .typical:
    baseline = route.normalTravelTime       // Mapbox duration_typical
else:  // .bestCase
    baseline = persisted no-traffic time for current direction
    fallback → route.normalTravelTime       // if no persisted baseline yet
    fallback → route.travelTime             // if nothing available (mood = green)
```

**Note on per-direction baselines:** The stored baseline is for the primary (fastest) route returned by the non-traffic profile. Alternate routes may take different roads with different no-traffic times. This is acceptable imprecision — the baseline represents "best case for the fastest path between home and work," not per-road-segment accuracy. The mood applies to the fastest route only; alternate routes continue using their own `normalTravelTime` for any per-route delay display.

### 2. Unified Mood Engine

Replace the two existing `TrafficMood` initializers with a single unified initializer:

```swift
init(currentTime: TimeInterval,
     baselineTime: TimeInterval,
     segmentCongestion: [CongestionLevel]?,
     hasMajorIncidents: Bool)
```

The `hasMajorIncidents` parameter is a pre-filtered boolean. The caller (`CommuteViewModel`) checks `RouteResult.incidents` for any with severity `.major` or `.severe` and passes the result. This keeps the mood engine simple while using the richer incident data from the model.

**The `.unknown` case** is handled before calling this initializer — if there is no route data, `CommuteViewModel.mood` returns `.unknown` without invoking the engine. The engine always produces `.clear`, `.moderate`, or `.heavy`.

**Algorithm (evaluated as an if/else-if chain, first match wins):**

```
1. if hasMajorIncidents → RED

2. delay = currentTime - baselineTime
   delayMinutes = delay / 60
   percentOver = delay / baselineTime

3. if delayMinutes < 3                              → GREEN  (minute floor)
   else if percentOver ≤ 0.15 AND delayMinutes < 5  → GREEN  (short commute grace)
   else if percentOver > 0.30 AND delayMinutes ≥ 10 → RED    (both % AND minutes required)
   else                                              → AMBER  (everything in between)

4. CONGESTION BUMP (applied after step 3, when segment data available):
   if >25% of segments are heavy/severe → bump result up one level
   (green → amber, amber → red, red stays red)

5. CAP: never exceed RED
```

**Key design decisions:**

- **Explicit if/else-if chain:** No overlapping conditions. Each input maps to exactly one mood before the congestion bump.
- **Minute floor (3 min):** Prevents short commutes from flashing amber over 1-2 minute fluctuations that are just noise.
- **Red requires both percentage AND minutes:** A 10-min commute at 14 min is 40% over but only 4 min late — that's amber, not red. Red should mean genuinely bad.
- **Congestion as bump, not primary:** Congestion data is a leading indicator that conditions are degrading, not the source of truth for overall trip quality. It can escalate the mood one level but never determines it alone.
- **Incidents bypass everything:** Major/severe incidents are always red regardless of duration math. Minor incidents are shown as badges in the UI but don't force a mood change.
- **`hasMajorIncidents` is pre-filtered by the caller:** `CommuteViewModel` checks `RouteResult.incidents` for severity `.major` or `.severe`. The `Route.hasIncidents` boolean (derived from advisory notices) is not used for mood — it conflates minor and major incidents.

### 3. Baseline Fetching

**When baselines are fetched:**

1. On address save — when user saves/updates home or work coordinates in Preferences
2. On Mapbox key change — when user adds/removes/changes their Mapbox key
3. Manual trigger — "Recalibrate" button in Preferences

**Fetch method by scenario:**

| Scenario | Method |
|---|---|
| Mapbox key available + `useMapboxBaseline` enabled | Call `mapbox/driving/{coords}` (non-traffic profile). Same API quota as driving-traffic — no additional cost per se, but counts as one request. Returns road-type-aware duration estimate without live traffic (accounts for road speeds, turn penalties, etc. — not a raw distance/speed calc). |
| Mapbox key available but `useMapboxBaseline` disabled | One-time `MKDirections` fetch (see MapKit note below) |
| No Mapbox key | Same MapKit approach |

**MapKit baseline quality note:** MapKit does not expose a guaranteed "no-traffic" duration. Omitting the departure date may still return a traffic-influenced estimate depending on Apple's internal model. As a fallback, if the returned time seems unreasonably close to the current traffic time, use the existing `estimateNormalTravelTime` heuristic (distance / 50 km/h). The MapKit baseline should be treated as a rough estimate — the Mapbox `driving` profile is the higher-quality source.

**Staleness policy:** No automatic re-fetch on a schedule. Road networks between fixed addresses are stable. Re-fetch only on address change, provider change, or manual trigger.

**Failure handling:** If a baseline fetch fails (network error, invalid coordinates, API error), the baseline fields remain nil (or retain their previous values if re-fetching). The UI shows "Baseline not available — check your connection and try again" in the summary line with the Recalibrate button enabled for retry. The mood engine falls back through the baseline selection chain (persisted → normalTravelTime → travelTime), so the app never breaks — it just uses a less precise baseline until the fetch succeeds.

**New file: `BaselineFetcher.swift`**

A small utility that encapsulates the fetch logic:

- Takes origin/destination coordinates + provider preference (Mapbox vs MapKit)
- For Mapbox: calls `https://api.mapbox.com/directions/v5/mapbox/driving/{coords}` (note: `driving`, not `driving-traffic`)
- For MapKit: uses `MKDirections` without a departure date
- Returns `TimeInterval` for each direction
- Called by PreferencesView on save and by the Recalibrate button

### 4. Settings UI

**Preferences → General tab — new "Traffic Comparison" section:**

```
Traffic Comparison
┌─────────────────────────────────────────────┐
│  Compare current traffic to:                │
│  ○ Best case (no traffic)     ← default     │
│  ○ Typical traffic                          │
│                                             │
│  ☑ Use Mapbox for baseline    [Recalibrate] │
│                                             │
│  Baseline: 22 min → work, 24 min → home    │
│  Set on Mar 25, 2026                        │
└─────────────────────────────────────────────┘
```

- **Radio picker** for compare mode (best case vs typical)
- **Checkbox** for "Use Mapbox for baseline" — only visible when user has a Mapbox key. When unchecked, falls back to MapKit estimate.
- **Recalibrate button** — triggers a fresh baseline fetch. Shows spinner during fetch. Disabled if addresses aren't configured.
- **Baseline summary** — shows stored baseline times per direction and fetch date. If no baseline set: "No baseline set — save your addresses to calibrate."

**Popover UI:** No layout changes. The mood badge `"+X min"` on the fastest route is calculated against the chosen baseline. Alternate routes' `"+X min"` badges continue to show the delta from the fastest route (as they do today) — these are relative comparisons between routes, not baseline comparisons.

**Developer settings:** Expose baseline values for testing/override.

### 5. Data Flow

**Typical poll cycle:**

```
1. CommuteViewModel.fetchRoute() fires
2. Provider returns RouteResult with routes
   - Each route has: travelTime, normalTravelTime, segmentCongestion
3. CommuteViewModel.mood computed property:
   a. Get fastestRoute
   b. Determine baseline:
      - "typical" mode → route.normalTravelTime
      - "bestCase" mode → settings.baselineToWorkTime/ToHomeTime
      - fallback → route.normalTravelTime
   c. Call TrafficMood(currentTime:baselineTime:segmentCongestion:hasMajorIncidents:)
4. UI updates: menu bar icon, popover badge, colors
```

**Baseline establishment:**

```
1. User saves addresses in Preferences (or taps Recalibrate)
2. PreferencesView calls BaselineFetcher.fetch(from:to:)
3. BaselineFetcher selects method:
   - Mapbox available + enabled → mapbox/driving/ endpoint
   - Otherwise → MKDirections estimate
4. Results stored: baselineToWorkTime, baselineToHomeTime, baselineFetchedAt
5. Mood recalculates on next poll automatically
```

### 6. Migration & Compatibility

- Existing users with no baseline stored → mood falls back to `route.normalTravelTime` (current behavior via `duration_typical`)
- No breaking changes — all new fields are additive with nil/default fallbacks
- First mood improvement happens once user opens Preferences and triggers a baseline fetch (either via address re-save or Recalibrate)

### 7. Files Changed

| File | Change |
|---|---|
| `DesignSystem.swift` | Replace two `TrafficMood` initializers with unified initializer |
| `CommuteViewModel.swift` | Update `mood` property to select baseline from settings |
| `SettingsStore.swift` | Add baseline fields, compare mode, useMapboxBaseline flag |
| `PreferencesView.swift` | Add Traffic Comparison section to General tab |
| **`BaselineFetcher.swift`** | **New** — baseline fetch logic for Mapbox and MapKit |
| `DeveloperSettingsView.swift` | Expose baseline values for testing; update existing mood preview to use new unified initializer |
| `MapboxDirectionsProvider.swift` | No changes |
| `MapKitProvider.swift` | No changes |
| `RouteResult.swift` | No changes |
