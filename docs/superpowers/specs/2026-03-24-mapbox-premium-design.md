# Mapbox Premium Traffic Data — Design Spec

## Overview

Add Mapbox Directions API as a premium traffic data source for Traffic Menubar. Free users keep Apple MapKit. Users unlock Mapbox by pasting their own API key (BYOK) or receiving a managed key. The integration is REST-only (no Mapbox SDK), using the Directions API with traffic-aware routing and per-segment congestion annotations.

## Goals

- Provide significantly more detailed traffic data (per-segment congestion, real free-flow ETAs, incident annotations)
- Upgrade the stylized route line, map polylines, and mood system with real congestion data
- Keep the free tier fully functional with Apple MapKit
- Design the networking layer so a proxy server can be added later without app changes
- No payment infrastructure for v1 — keys distributed manually

## Non-Goals

- No Mapbox Maps SDK — we use the REST Directions API only
- No traffic tiles for off-route visualization
- No in-app purchase or subscription management
- No backend proxy server (designed for, but not built yet)
- No changes to PollScheduler, LocationManager, or GeocodingService

## Architecture

### Approach: Provider Swap

A new `MapboxDirectionsProvider` implements the existing `TrafficProvider` protocol. At runtime, if a Mapbox key is configured in settings, the Mapbox provider is used. Otherwise, MapKit is the default. This is a clean swap — one provider active at a time.

### Data Flow

```
Settings (API key) → CommuteViewModel (provider selection) → MapboxDirectionsProvider or MapKitProvider
    → RouteResult (with optional congestion data) → Views (render richer data when available)
```

## Data Model Changes

### New: CongestionLevel enum

```swift
enum CongestionLevel: String, Codable {
    case unknown
    case low
    case moderate
    case heavy
    case severe
}
```

### Modified: Route struct

Add one optional field:

```swift
let segmentCongestion: [CongestionLevel]?  // nil for MapKit, populated by Mapbox
```

Each element corresponds to a segment between consecutive `polylineCoordinates`. When nil, all views fall back to current behavior.

### Existing models unchanged

`RouteResult`, `TrafficIncident`, `Coordinate`, `CommuteDirection` — no structural changes. `RouteResult.incidents` will be populated by Mapbox (currently always empty from MapKit).

## MapboxDirectionsProvider

### API Call

```
GET {baseURL}/directions/v5/mapbox/driving-traffic/{originLng},{originLat};{destLng},{destLat}
```

Query parameters:
- `access_token` — the Mapbox API key
- `alternatives=true` — request alternate routes
- `annotations=congestion,duration` — per-segment congestion levels and durations
- `geometries=polyline6` — high-precision encoded polyline
- `overview=full` — full route geometry

### baseURL Abstraction

Default: `https://api.mapbox.com`. Stored as a configurable property so that migrating to a proxy server later only requires changing this URL and swapping the auth mechanism (from `access_token` query param to a custom auth header).

### Response Parsing

Key fields extracted from the Mapbox JSON response:

| Mapbox field | Maps to |
|---|---|
| `routes[].duration` | `Route.travelTime` (traffic-aware) |
| `routes[].duration_typical` | `Route.normalTravelTime` (free-flow) |
| `routes[].distance` | `Route.distance` |
| `routes[].geometry` | Decoded to `Route.polylineCoordinates` |
| `routes[].legs[].annotation.congestion` | `Route.segmentCongestion` |
| `routes[].legs[].incidents` | `RouteResult.incidents` |

### Codable Models

A `MapboxModels.swift` file contains Codable structs mirroring the Mapbox Directions API response structure (routes, legs, annotations, geometry).

### Polyline Decoding

Mapbox uses the encoded polyline algorithm (polyline6 precision). A pure-Swift decoder converts the encoded string to `[Coordinate]`. No external dependency needed.

### Error Handling

Maps to existing `TrafficProviderError`:
- 401 → `.invalidAPIKey` (new case)
- No routes in response → `.noRouteFound`
- Network/timeout → `.networkError`
- 429 (rate limited) → `.networkError` (retried on next poll)

## Settings & Key Management

### New SettingsStore Fields

```swift
@Published var mapboxAPIKey: String        // The stored API key
@Published var mapboxKeySource: String     // "none" | "byok" | "managed"
```

### Computed Property

```swift
var effectiveMapboxKey: String? {
    mapboxKeySource != "none" && !mapboxAPIKey.isEmpty ? mapboxAPIKey : nil
}
```

### Provider Selection in CommuteViewModel

```swift
var activeProvider: TrafficProvider {
    if let key = settings.effectiveMapboxKey {
        return MapboxDirectionsProvider(apiKey: key)
    }
    return MapKitProvider()
}
```

Provider swaps automatically when the key changes — no app restart needed.

### No Key Validation on Save

If the key is invalid, the next fetch fails, `consecutiveFailures` increments, and the existing error UI appears. The settings UI shows a warning hint after repeated failures. Users can remove the key to revert to MapKit.

## Settings UI — Premium Teaser

The "TRAFFIC PROVIDER" section in the General tab has three states:

### State 1: Free Tier (default)

- Apple Maps shown as active provider with green checkmark
- Below it: a "Mapbox Premium" teaser card with purple accent
  - Lock icon + "Mapbox Premium" heading
  - Feature list: "Real-time congestion data, Per-segment traffic colors, Incident alerts, Accurate free-flow ETAs"
  - Two buttons: "I have a Mapbox key" (expands to State 2) and "Get Premium Access" (links to contact/email)

### State 2: BYOK Key Input

- Apple Maps row dimmed
- Mapbox card expanded with key input field
- Monospace placeholder text
- "Save Key" button (stores key, sets `mapboxKeySource = "byok"`) and "Cancel" link
- Helper text: "Get a free key at mapbox.com/account — Includes 100k directions requests/month"

### State 3: Mapbox Active

- Apple Maps row dimmed
- Mapbox card shows active state with green top stripe
- Badge: "BYOK" or "PREMIUM" depending on `mapboxKeySource`
- Masked key display (first 4 chars + dots)
- "Remove Key" link (clears key, reverts to MapKit) with "Falls back to Apple Maps" hint

### Design Language

Purple accent (#a78bfa / #818cf8) for Mapbox premium branding, distinct from the app's green theme. Dark card backgrounds (rgba(167,139,250,0.08)) with proper contrast for dark mode readability.

## Visualization Upgrades

All upgrades are conditional — they activate when `segmentCongestion` is non-nil and fall back to current behavior when nil.

### StylizedRouteLineView

**Current:** Single gradient based on overall delay ratio (green → amber → red).

**With congestion data:** Multi-segment line where each segment is colored by its actual congestion level:
- `low` → green (#4DAD80)
- `moderate` → amber (#FDC21C)
- `heavy` → red (#F76F6F)
- `severe` → dark red (#D32F2F)
- `unknown` → gray

The draw animation (left-to-right with `drawProgress`) is preserved. Gradient stops are now driven by the congestion array positions mapped to the line width.

### MapPreviewView

**Current:** Primary route as solid green `MKPolyline`, alternates as dashed white.

**With congestion data:** Primary route rendered as multiple `MKPolyline` segments, each colored by its congestion level. Uses the existing `TaggedPolyline` pattern extended with a congestion color property. Alternate routes remain dashed white (unchanged).

### Mood System

**Current initializer (kept for MapKit):**
```swift
init(delayMinutes: Int, hasIncidents: Bool)
```

**New initializer for Mapbox data:**
```swift
init(segmentCongestion: [CongestionLevel]) {
    let totalSegments = segmentCongestion.count
    let severeOrHeavy = segmentCongestion.filter { $0 == .severe || $0 == .heavy }.count
    let ratio = Double(severeOrHeavy) / Double(totalSegments)

    if ratio > 0.3 { self = .heavy }
    else if ratio > 0.1 { self = .moderate }
    else { self = .clear }
}
```

CommuteViewModel's `mood` property checks for congestion data first, falls back to delay-based calculation.

## Error Handling & Fallback

- **No automatic fallback to MapKit.** If Mapbox fails, the app shows the existing error state. The user decides whether to remove the key.
- **Invalid key (401):** After 3 consecutive failures, show error state. Settings UI hints that the key may be invalid.
- **Rate limit (429):** Treated as network error, retried on next poll cycle.
- **Network errors:** Identical to current MapKit error handling via `consecutiveFailures`.

## File Changes

### New Files
- `Providers/MapboxDirectionsProvider.swift` — REST client, response parsing, polyline decoding
- `Providers/MapboxModels.swift` — Codable structs for Mapbox API response

### Modified Files
- `Models/RouteResult.swift` — add `CongestionLevel` enum, add `segmentCongestion` to `Route`
- `Providers/TrafficProvider.swift` — add `.invalidAPIKey` error case
- `Utilities/SettingsStore.swift` — add `mapboxAPIKey`, `mapboxKeySource`, `effectiveMapboxKey`
- `ViewModels/CommuteViewModel.swift` — provider selection based on settings, updated mood calculation
- `Views/StylizedRouteLineView.swift` — multi-segment congestion coloring
- `Views/MapPreviewView.swift` — per-segment colored polylines
- `Views/DesignSystem.swift` — new `TrafficMood` initializer, congestion color helpers
- `Views/PreferencesView.swift` — three-state premium Traffic Provider UI
- `Providers/MockTrafficProvider.swift` — add mock congestion data for dev testing

## Future Considerations (not in scope)

- **Proxy server migration:** baseURL abstraction makes this a config change on the app side. Server-side work (auth, rate limiting, Stripe/Paddle integration) is separate.
- **Payment infrastructure:** When ready, "Get Premium Access" button links to an external payment flow that delivers a managed key.
- **Usage tracking:** Could display Mapbox free tier usage in settings (requires tracking request counts locally or via the proxy).
