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
| `baselineCompareMode` | `String` | `"bestCase"` | `"bestCase"` or `"typical"` |
| `useMapboxBaseline` | `Bool` | `true` | When false, uses MapKit even if Mapbox key exists |
| `baselineFetchedAt` | `Date?` | `nil` | Timestamp for display ("Baseline set on Mar 25") |

**Existing fields unchanged:**

- `Route.normalTravelTime` continues to hold Mapbox `duration_typical` (used when compare mode is "typical")
- `Route.travelTime` continues to hold current with-traffic duration

**Baseline selection logic:**

```
if settings.baselineCompareMode == "typical":
    baseline = route.normalTravelTime       // Mapbox duration_typical
else:  // "bestCase"
    baseline = persisted no-traffic time for current direction
    fallback → route.normalTravelTime       // if no persisted baseline yet
    fallback → route.travelTime             // if nothing available (mood = green)
```

### 2. Unified Mood Engine

Replace the two existing `TrafficMood` initializers with a single unified initializer:

```swift
init(currentTime: TimeInterval,
     baselineTime: TimeInterval,
     segmentCongestion: [CongestionLevel]?,
     hasIncidents: Bool)
```

**Algorithm:**

```
1. INCIDENTS CHECK (first):
   - If hasIncidents with severity >= major → RED
   - Skip remaining logic

2. DURATION COMPARISON:
   delay = currentTime - baselineTime
   percentOver = delay / baselineTime

3. PRIMARY MOOD from thresholds:
   - GREEN:  delay < 3 min                        (minute floor — tiny delays are noise)
   - GREEN:  percentOver ≤ 15% AND delay < 5 min  (short commutes get grace)
   - AMBER:  percentOver ≤ 30% OR delay 5–14 min
   - RED:    percentOver > 30% AND delay ≥ 10 min  (requires both % AND minutes)

4. CONGESTION BUMP (when segment data available):
   - If >25% of segments are heavy/severe → bump mood up one level
     (green → amber, amber → red, red stays red)
   - This is a leading indicator: congestion builds before overall duration spikes

5. CAP: never exceed RED, never go below GREEN
```

**Key design decisions:**

- **Minute floor (3 min):** Prevents short commutes from flashing amber over 1-2 minute fluctuations that are just noise.
- **Red requires both percentage AND minutes:** A 10-min commute at 14 min is 40% over but only 4 min late — that's amber, not red. Red should mean genuinely bad.
- **Congestion as bump, not primary:** Congestion data is a leading indicator that conditions are degrading, not the source of truth for overall trip quality. It can escalate the mood one level but never determines it alone.
- **Incidents bypass everything:** Major incidents are always red regardless of duration math.

### 3. Baseline Fetching

**When baselines are fetched:**

1. On address save — when user saves/updates home or work coordinates in Preferences
2. On Mapbox key change — when user adds/removes/changes their Mapbox key
3. Manual trigger — "Recalibrate" button in Preferences

**Fetch method by scenario:**

| Scenario | Method |
|---|---|
| Mapbox key available + `useMapboxBaseline` enabled | Call `mapbox/driving/{coords}` (non-traffic profile). Free endpoint. Returns pure distance-based duration. |
| Mapbox key available but `useMapboxBaseline` disabled | One-time `MKDirections` fetch with no departure date |
| No Mapbox key | Same MapKit approach |

**Staleness policy:** No automatic re-fetch on a schedule. Road networks between fixed addresses are stable. Re-fetch only on address change, provider change, or manual trigger.

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

**Popover UI:** No layout changes. The existing mood badge `"+X min"` delay is now calculated against the chosen baseline instead of `duration_typical`.

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
   c. Call TrafficMood(currentTime:baselineTime:segmentCongestion:hasIncidents:)
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
| `DeveloperSettingsView.swift` | Expose baseline values for testing |
| `MapboxDirectionsProvider.swift` | No changes |
| `MapKitProvider.swift` | No changes |
| `RouteResult.swift` | No changes |
