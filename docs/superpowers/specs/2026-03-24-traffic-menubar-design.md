# Traffic Menubar — Design Spec

A macOS menubar app that shows your live commute time at a glance.

## Overview

A pure SwiftUI menubar app (macOS 13+) using `MenuBarExtra`. No main window — the menubar is the entire UI. Shows commute duration in the menubar, with a popover containing detailed info, incident alerts, and a route map preview.

## Core Decisions

- **Framework:** Swift + SwiftUI, `MenuBarExtra` API (macOS 13 Ventura+)
- **Traffic data:** Apple MapKit (`MKDirections`) for v1 — free, no API key, traffic-aware ETAs. Provider protocol enables swapping to Google Maps, HERE, etc. later.
- **Polling:** Smart scheduling — frequent during commute hours, infrequent otherwise.
- **Direction detection:** Location-based (CLLocationManager) with time-based fallback if location access is denied.

## Architecture

```
┌─────────────────────────────────┐
│         MenuBarExtra            │  SwiftUI app entry point
│  (icon: "32m" or "32m ⚠")      │
├─────────────────────────────────┤
│         PopoverView             │  Compact stack layout
│  (time, ETA, incidents, map)    │
├─────────────────────────────────┤
│       CommuteViewModel          │  Owns state, drives polling
├──────────┬──────────┬───────────┤
│ Traffic  │ Location │ Settings  │
│ Provider │ Manager  │ Store     │
│(protocol)│(CLLoc.)  │(UserDef.) │
└──────────┴──────────┴───────────┘
```

### Key Components

- **`TrafficProvider` protocol** — `fetchRoute(from:to:) async throws -> RouteResult`. MapKit is the first conformer. New providers are added by dropping a file in `Providers/` and conforming.
- **`CommuteViewModel`** — the brain. Manages polling timer, determines commute direction, holds current `RouteResult`.
- **`LocationManager`** — wraps `CLLocationManager`. Determines proximity to home/work. Publishes current state.
- **`SettingsStore`** — persists addresses, polling preferences, launch-at-login via `@AppStorage` / `UserDefaults`.
- **`PollScheduler`** — encapsulates smart interval logic, sleep/wake handling.
- **`GeocodingService`** — converts address strings to coordinates via `CLGeocoder`. Caches resolved coordinates.

## Data Model

```swift
struct RouteResult {
    let travelTime: TimeInterval        // seconds, with traffic
    let normalTravelTime: TimeInterval   // seconds, without traffic
    let eta: Date
    let incidents: [TrafficIncident]
    let routePolyline: [Coordinate]      // for map preview
}

struct TrafficIncident {
    let description: String
    let severity: IncidentSeverity       // .minor, .major, .severe
    let location: Coordinate
}

struct Coordinate {
    let latitude: Double
    let longitude: Double
}

enum CommuteDirection {
    case toWork
    case toHome
}

protocol TrafficProvider {
    func fetchRoute(from: Coordinate, to: Coordinate) async throws -> RouteResult
}
```

## Smart Polling

### Commute Hours (configurable, defaults)

- Morning: 7:00 AM – 9:30 AM
- Evening: 4:00 PM – 7:00 PM

### Intervals

- During commute hours: every 3 minutes
- Outside commute hours: every 15 minutes
- Screen locked / sleep: pause polling, resume on wake

### Implementation

- Async loop with `Task.sleep` firing at the current interval
- Re-evaluate interval after each fetch (commute hour transitions)
- Listen for `NSWorkspace.didWakeNotification` / `willSleepNotification`
- Rate limit floor: 1 request per minute minimum, regardless of settings

### Direction Detection

1. Check `CLLocationManager` for current location
2. Within ~500m of home → `.toWork`
3. Within ~500m of work → `.toHome`
4. Location unavailable or neither → time-based fallback (before noon = `.toWork`, after noon = `.toHome`)

## UI Design

### Menubar Icon (MenuBarExtra label)

- Normal: `32m` (text)
- Incident: `32m ⚠` (SF Symbol `exclamationmark.triangle.fill`, yellow)
- Loading: `--m`
- Error: `!` (after 3 consecutive failures)

### Popover (Compact Stack Layout)

```
┌──────────────────────────┐
│ COMMUTE HOME             │
│ 47 min          ETA      │
│ (large)       6:12 PM    │
├──────────────────────────┤
│ ⚠ Accident on I-85 N    │  ← only when incidents exist
│   +12 min vs usual       │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │    Map Preview       │ │  MKMapView with route overlay
│ │  (green) ── (red)    │ │
│ └──────────────────────┘ │
├──────────────────────────┤
│ Updated 2m ago    ⚙      │
└──────────────────────────┘
```

### Inline Quick Settings (gear icon)

- Swap direction (To Work / To Home) manual override
- Refresh now

### Preferences Window (separate NSWindow)

- Home address (text field with geocoding)
- Work address (text field with geocoding)
- Commute hours (morning start/end, evening start/end)
- Polling intervals (commute / off-peak)
- Launch at login toggle (off by default, via `SMAppService`)
- Traffic provider selection (MapKit only for now, dropdown ready for future)

### Map Preview

- `MKMapView` wrapped in `NSViewRepresentable`
- Route polyline from origin to destination
- Green dot at origin, red dot at destination
- Incident markers (⚠) on route if available
- Non-interactive — visual preview only

## Error Handling

### Network Errors

- On fetch failure: keep displaying last successful result, "Updated Xm ago" shows staleness
- After 3 consecutive failures: subtle error indicator in popover (not menubar)
- Retry on next scheduled poll

### Address Geocoding

- Geocode on entry in settings via `CLGeocoder`
- Store resolved `Coordinate` — no re-geocoding per fetch
- Inline error in settings if geocoding fails

### Location Permissions

- Request "When In Use" on first launch
- If denied: silently fall back to time-based direction, no nagging
- Note in settings: "Location access enables automatic direction detection"

### First Launch

- Opens preferences window immediately — addresses required before anything works
- Menubar shows `--m` until first successful fetch
- No onboarding wizard

### MapKit Limitations

- `MKDirections` may not return incident data — incident section stays hidden
- If no traffic-aware time returned: use non-traffic estimate, hide "+X min vs usual"

## Project Structure

```
traffic-menubar/
├── TrafficMenubar/
│   ├── TrafficMenubarApp.swift          # App entry, MenuBarExtra setup
│   ├── Models/
│   │   ├── RouteResult.swift            # RouteResult, TrafficIncident, Coordinate
│   │   └── CommuteDirection.swift       # .toWork / .toHome enum
│   ├── Providers/
│   │   ├── TrafficProvider.swift        # Protocol definition
│   │   └── MapKitProvider.swift         # Apple MapKit implementation
│   ├── ViewModels/
│   │   └── CommuteViewModel.swift       # Polling, direction logic, state
│   ├── Services/
│   │   ├── LocationManager.swift        # CLLocationManager wrapper
│   │   └── GeocodingService.swift       # Address → Coordinate resolution
│   ├── Views/
│   │   ├── PopoverView.swift            # Main compact stack layout
│   │   ├── MapPreviewView.swift         # MKMapView wrapped for SwiftUI
│   │   ├── IncidentBannerView.swift     # Warning banner
│   │   ├── QuickSettingsView.swift      # Inline gear menu
│   │   └── PreferencesView.swift        # Full settings window
│   └── Utilities/
│       ├── SettingsStore.swift          # UserDefaults / @AppStorage
│       └── PollScheduler.swift          # Smart interval timer logic
├── TrafficMenubar.xcodeproj
└── .gitignore
```

## Future Extensibility

- **New traffic providers:** Conform to `TrafficProvider` protocol, add to `Providers/`, wire up in settings dropdown.
- **Multiple routes:** The data model supports it — `CommuteViewModel` could hold an array of `RouteResult`.
- **Widgets:** The `CommuteViewModel` could be shared with a macOS widget target via an App Group.
