# Developer Settings Pane — Design Spec

## Overview

A developer settings window for the Traffic Menubar app that enables testing different UI states, data scenarios, and design variations without relying on real traffic data. Accessible via a "Developer Mode" toggle in General preferences, it opens as a standalone window that can float alongside the popover for real-time feedback.

## Architecture

### Approach: Mock Provider + Design Overrides

Two new observable objects provide full control:

**`MockTrafficProvider`** — conforms to the existing `TrafficProvider` protocol. Instead of hitting MapKit, it returns a `RouteResult` built from developer-controlled values:
- `travelTimeMinutes` (slider: 1–120)
- `normalTravelTimeMinutes` (slider: 1–120, for computing delay)
- `incidents` toggle + count picker (1–3) + severity selector (minor/major/severe)
- A hardcoded sample polyline (~20 coordinates) so the map always renders

**`DevDesignOverrides`** — a separate `ObservableObject` for visual tweaks:
- `moodOverride: TrafficMood?` — force a mood regardless of data
- `fontScale: CGFloat` — multiplier against `Design` constants
- Injected into the SwiftUI environment so views can read it without ViewModel changes

### ViewModel Changes

`CommuteViewModel`:
- `provider` becomes `private(set) var` (currently `private let`)
- New `@Published var isDevMode = false`
- `enableDevMode()` — sets `isDevMode = true`, stops polling, swaps provider to `MockTrafficProvider`
- `disableDevMode()` — sets `isDevMode = false`, restores `MapKitProvider`, resumes polling
- `updateFromMock(_ route: RouteResult)` — directly sets `currentRoute`, `lastUpdated`, `consecutiveFailures`, and `direction`

### SettingsStore Changes

- New `developerModeEnabled: Bool` persisted to UserDefaults

## Developer Window

### Access

- Toggle "Developer Mode" in Preferences → General tab
- When enabled, a "Open Developer Settings" button appears
- Clicking it opens a separate `Window("Developer", id: "developer")` scene
- Window size: ~400×600

### Sections

#### 1. Master Toggle
- Orange-accented banner showing dev mode status
- Toggle to enable/disable (pauses polling, switches data source)
- Status text: "Polling paused · Mock data in use"

#### 2. App State
- **Force state** — segmented control: Normal / Loading / Error / Empty
- **Direction** — segmented control: To Work / To Home
- **Consecutive failures** — stepper (0–10), drives the offline indicator at ≥3

#### 3. Route Data
- **Travel time** — slider (1–120 min) with live readout
- **Normal time (baseline)** — slider (1–120 min) with live readout
- **Computed display** — shows resulting delay and mood (read-only, derived from the two sliders)

#### 4. Incidents
- **Include incidents** — toggle
- **Number of incidents** — stepper (1–3)
- **Max severity** — segmented control: Minor / Major / Severe
- Generates placeholder incident descriptions based on severity

#### 5. Design Overrides
- **Force mood** — segmented: Auto / ☀️ Clear / 🌤 Moderate / 🌧 Heavy
- **Font scale** — slider (0.5×–2.0×)

#### 6. Quick Presets
One-click buttons that configure a complete scenario:

| Preset | Travel | Normal | Incidents | Failures | State |
|--------|--------|--------|-----------|----------|-------|
| ☀️ Clear roads | 25 min | 25 min | none | 0 | normal |
| 🌤 Moderate | 35 min | 25 min | none | 0 | normal |
| 🌧 Heavy + incidents | 55 min | 25 min | 2 (major+severe) | 0 | normal |
| 💤 Empty state | — | — | — | 0 | empty (nil route) |
| ⚡ Loading | — | — | — | 0 | isLoading=true |
| ☁️ Offline | — | — | — | 3 | error |

## Integration

### TrafficMenubarApp.swift
- Register `Window("Developer", id: "developer")` scene
- Pass the same `viewModel` instance so changes reflect immediately
- Add `OpenDevWindowAction` environment key (same pattern as `OpenPreferencesAction`)

### PreferencesView
- Add "Developer Mode" toggle to General tab
- When enabled, show "Open Developer Settings" button

### PopoverView
- When `viewModel.isDevMode` is true, show a subtle orange "DEV" badge in the footer

### Menu Bar
- No changes — reads from `viewModel.currentRoute` which mock data already flows through

## Data Flow

```
Dev Window slider changes →
  MockTrafficProvider properties update →
    MockTrafficProvider builds RouteResult →
      ViewModel.updateFromMock(route) called →
        @Published currentRoute changes →
          PopoverView re-renders
          Menu bar label re-renders
```

All synchronous on `@MainActor`. No async gaps, no race conditions (poll loop is stopped).

### Sample Polyline
Hardcoded array of ~20 coordinates forming a plausible route curve, used for map preview rendering in dev mode.

### Incident Generation
Placeholder descriptions based on severity:
- Minor: "Minor slowdown ahead"
- Major: "Construction on main route"
- Severe: "Major accident — expect significant delays"

## Testable Scenarios

- All 4 popover states: normal, loading, error/offline, empty
- All 3 moods with color/emoji/copy transitions
- Incident banner with 1–3 incidents at varying severities
- Menu bar text variants: "32m", "32m ◑", "32m ⚠", "—m"
- Direction label: "To Work" ↔ "To Home"
- Mood threshold boundaries: 0 delay (clear), 5 min (moderate), 15 min (heavy)
- Incidents present but low delay (still heavy)
- Transition from error → normal
- Font scaling across the popover

## Out of Scope

- Network simulation (latency, timeouts) — mock bypasses network entirely
- Real geocoding testing — addresses stay as configured in Preferences
- PollScheduler testing — paused during dev mode
- Map interaction testing (zoom/pan) — map preview is read-only

## Files to Create

- `TrafficMenubar/Providers/MockTrafficProvider.swift`
- `TrafficMenubar/ViewModels/DevDesignOverrides.swift`
- `TrafficMenubar/Views/DeveloperSettingsView.swift`

## Files to Modify

- `TrafficMenubar/ViewModels/CommuteViewModel.swift` — provider swapping, dev mode state
- `TrafficMenubar/Utilities/SettingsStore.swift` — `developerModeEnabled` property
- `TrafficMenubar/Views/PreferencesView.swift` — dev mode toggle in General tab
- `TrafficMenubar/Views/PopoverView.swift` — DEV badge, design override environment reads
- `TrafficMenubar/TrafficMenubarApp.swift` — developer window scene registration
- `TrafficMenubar/Views/DesignSystem.swift` — font scale support via DevDesignOverrides
