# Mapbox Premium Traffic Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Mapbox Directions API as a premium traffic data provider that users unlock via BYOK or managed key, upgrading the stylized line, map polylines, mood system, and route data with real per-segment congestion information.

**Architecture:** New `MapboxDirectionsProvider` conforms to existing `TrafficProvider` protocol. Provider is selected at runtime based on whether a Mapbox API key is configured in `SettingsStore`. Data models gain optional `segmentCongestion` field; views check for it and render richer visuals when present, falling back to current behavior when absent.

**Tech Stack:** Swift 5.9, SwiftUI, MapKit (existing), URLSession (for Mapbox REST calls), Codable (JSON parsing)

**Spec:** `docs/superpowers/specs/2026-03-24-mapbox-premium-design.md`

---

### Task 1: Data Model — CongestionLevel and Route Extension

**Files:**
- Modify: `TrafficMenubar/Models/RouteResult.swift`

This task adds the `CongestionLevel` enum and the optional `segmentCongestion` field to `Route`. Every call site that constructs a `Route` must be updated to pass the new parameter.

- [ ] **Step 1: Add CongestionLevel enum to RouteResult.swift**

Add above the `Route` struct:

```swift
enum CongestionLevel: String, Codable {
    case unknown
    case low
    case moderate
    case heavy
    case severe
}
```

- [ ] **Step 2: Add segmentCongestion to Route struct**

Add as the last field in `Route`:

```swift
let segmentCongestion: [CongestionLevel]?
```

- [ ] **Step 3: Update MapKitProvider to pass nil for segmentCongestion**

In `TrafficMenubar/Providers/MapKitProvider.swift`, update the `Route(...)` initializer call inside the `.map` closure to include `segmentCongestion: nil`.

- [ ] **Step 4: Update MockTrafficProvider to pass nil for segmentCongestion**

In `TrafficMenubar/Providers/MockTrafficProvider.swift`, update both `Route(...)` initializer calls (primary and alternate routes in `buildRoutes()`) to include `segmentCongestion: nil`.

- [ ] **Step 5: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add TrafficMenubar/Models/RouteResult.swift TrafficMenubar/Providers/MapKitProvider.swift TrafficMenubar/Providers/MockTrafficProvider.swift
git commit -m "feat: add CongestionLevel enum and segmentCongestion to Route model"
```

---

### Task 2: TrafficProvider Error Extension

**Files:**
- Modify: `TrafficMenubar/Providers/TrafficProvider.swift`

- [ ] **Step 1: Add invalidAPIKey case to TrafficProviderError**

Add a new case to the enum:

```swift
case invalidAPIKey
```

And its description in `errorDescription`:

```swift
case .invalidAPIKey:
    return "Invalid API key. Check your Mapbox key in Settings."
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Providers/TrafficProvider.swift
git commit -m "feat: add invalidAPIKey error case to TrafficProviderError"
```

---

### Task 3: Mapbox Response Models

**Files:**
- Create: `TrafficMenubar/Providers/MapboxModels.swift`

These Codable structs mirror the Mapbox Directions API v5 JSON response. Kept in a separate file from the provider for clarity.

- [ ] **Step 1: Create MapboxModels.swift**

```swift
import Foundation

// MARK: - Mapbox Directions API v5 Response Models

struct MapboxDirectionsResponse: Codable {
    let code: String
    let routes: [MapboxRoute]
}

struct MapboxRoute: Codable {
    let duration: Double
    let durationTypical: Double?
    let distance: Double
    let geometry: String
    let legs: [MapboxLeg]

    enum CodingKeys: String, CodingKey {
        case duration, distance, geometry, legs
        case durationTypical = "duration_typical"
    }
}

struct MapboxLeg: Codable {
    let annotation: MapboxAnnotation?
    let incidents: [MapboxIncident]?
}

struct MapboxAnnotation: Codable {
    let congestion: [String]?
    let duration: [Double]?
}

struct MapboxIncident: Codable {
    let description: String?
    let impact: String?
    let geometryIndexStart: Int?
    let geometryIndexEnd: Int?

    enum CodingKeys: String, CodingKey {
        case description, impact
        case geometryIndexStart = "geometry_index_start"
        case geometryIndexEnd = "geometry_index_end"
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Providers/MapboxModels.swift
git commit -m "feat: add Codable models for Mapbox Directions API response"
```

---

### Task 4: MapboxDirectionsProvider

**Files:**
- Create: `TrafficMenubar/Providers/MapboxDirectionsProvider.swift`

The core provider: builds the URL, makes the REST call, parses the response, decodes polylines, and maps everything to our `RouteResult` model.

- [ ] **Step 1: Create MapboxDirectionsProvider.swift with polyline decoder**

The polyline6 decoder is a well-known algorithm — decode encoded strings to `[Coordinate]`:

```swift
import Foundation

final class MapboxDirectionsProvider: TrafficProvider {
    private let apiKey: String
    private let baseURL: String

    init(apiKey: String, baseURL: String = "https://api.mapbox.com") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func fetchRoutes(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
        let urlString = "\(baseURL)/directions/v5/mapbox/driving-traffic/"
            + "\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)"
            + "?access_token=\(apiKey)"
            + "&alternatives=true"
            + "&annotations=congestion,duration"
            + "&geometries=polyline6"
            + "&overview=full"

        guard let url = URL(string: urlString) else {
            throw TrafficProviderError.networkError(URLError(.badURL))
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw TrafficProviderError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                throw TrafficProviderError.invalidAPIKey
            }
            if httpResponse.statusCode != 200 {
                throw TrafficProviderError.networkError(
                    URLError(URLError.Code(rawValue: httpResponse.statusCode))
                )
            }
        }

        let directionsResponse: MapboxDirectionsResponse
        do {
            directionsResponse = try JSONDecoder().decode(MapboxDirectionsResponse.self, from: data)
        } catch {
            throw TrafficProviderError.networkError(error)
        }

        guard directionsResponse.code == "Ok", !directionsResponse.routes.isEmpty else {
            throw TrafficProviderError.noRouteFound
        }

        let routes: [Route] = Array(directionsResponse.routes.prefix(3)).enumerated().map { index, mbRoute in
            let coordinates = decodePolyline6(mbRoute.geometry)
            let congestion = combineLegCongestion(mbRoute.legs)
            let name = index == 0 ? "Fastest Route" : "Alternate \(index)"

            return Route(
                name: name,
                travelTime: mbRoute.duration,
                normalTravelTime: mbRoute.durationTypical ?? mbRoute.duration,
                distance: mbRoute.distance,
                polylineCoordinates: coordinates,
                mkPolyline: nil,
                advisoryNotices: extractAdvisories(mbRoute.legs),
                segmentCongestion: congestion
            )
        }

        let sortedRoutes = routes.sorted { $0.travelTime < $1.travelTime }
        let incidents = extractIncidents(from: directionsResponse.routes.first, coordinates: sortedRoutes.first?.polylineCoordinates ?? [])

        return RouteResult(
            routes: sortedRoutes,
            incidents: incidents,
            fetchedAt: Date()
        )
    }

    // MARK: - Polyline6 Decoding

    private func decodePolyline6(_ encoded: String) -> [Coordinate] {
        var coordinates: [Coordinate] = []
        var index = encoded.startIndex
        var lat: Int = 0
        var lng: Int = 0

        while index < encoded.endIndex {
            lat += decodeValue(from: encoded, index: &index)
            lng += decodeValue(from: encoded, index: &index)
            coordinates.append(Coordinate(
                latitude: Double(lat) / 1e6,
                longitude: Double(lng) / 1e6
            ))
        }

        return coordinates
    }

    private func decodeValue(from string: String, index: inout String.Index) -> Int {
        var result = 0
        var shift = 0

        while index < string.endIndex {
            let char = Int(string[index].asciiValue! - 63)
            index = string.index(after: index)
            result |= (char & 0x1F) << shift
            shift += 5
            if char < 0x20 { break }
        }

        return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    }

    // MARK: - Response Mapping Helpers

    private func combineLegCongestion(_ legs: [MapboxLeg]) -> [CongestionLevel] {
        legs.flatMap { leg in
            (leg.annotation?.congestion ?? []).map { raw in
                CongestionLevel(rawValue: raw) ?? .unknown
            }
        }
    }

    private func extractAdvisories(_ legs: [MapboxLeg]) -> [String] {
        legs.flatMap { leg in
            (leg.incidents ?? []).compactMap { $0.description }
        }
    }

    private func extractIncidents(from route: MapboxRoute?, coordinates: [Coordinate]) -> [TrafficIncident] {
        guard let route else { return [] }
        return route.legs.flatMap { leg in
            (leg.incidents ?? []).compactMap { incident -> TrafficIncident? in
                guard let description = incident.description else { return nil }
                let severity: IncidentSeverity
                switch incident.impact {
                case "critical": severity = .severe
                case "major": severity = .major
                default: severity = .minor
                }
                let locationIndex = incident.geometryIndexStart ?? 0
                let location = locationIndex < coordinates.count
                    ? coordinates[locationIndex]
                    : coordinates.first ?? Coordinate(latitude: 0, longitude: 0)
                return TrafficIncident(description: description, severity: severity, location: location)
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Providers/MapboxDirectionsProvider.swift
git commit -m "feat: add MapboxDirectionsProvider with REST client and polyline6 decoder"
```

---

### Task 5: SettingsStore — Mapbox Key Management

**Files:**
- Modify: `TrafficMenubar/Utilities/SettingsStore.swift`

- [ ] **Step 1: Add Mapbox settings properties**

Add after the `developerModeEnabled` property:

```swift
@Published var mapboxAPIKey: String {
    didSet { UserDefaults.standard.set(mapboxAPIKey, forKey: "mapboxAPIKey") }
}
@Published var mapboxKeySource: String {
    didSet { UserDefaults.standard.set(mapboxKeySource, forKey: "mapboxKeySource") }
}

var effectiveMapboxKey: String? {
    mapboxKeySource != "none" && !mapboxAPIKey.isEmpty ? mapboxAPIKey : nil
}
```

- [ ] **Step 2: Initialize the new properties in init()**

Add at the end of the `init()` method, after the `developerModeEnabled` line:

```swift
self.mapboxAPIKey = defaults.string(forKey: "mapboxAPIKey") ?? ""
self.mapboxKeySource = defaults.string(forKey: "mapboxKeySource") ?? "none"
```

- [ ] **Step 3: Add helper methods for key management**

Add after `effectiveMapboxKey`:

```swift
func setMapboxKey(_ key: String, source: String) {
    mapboxAPIKey = key
    mapboxKeySource = source
}

func clearMapboxKey() {
    mapboxAPIKey = ""
    mapboxKeySource = "none"
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TrafficMenubar/Utilities/SettingsStore.swift
git commit -m "feat: add Mapbox API key management to SettingsStore"
```

---

### Task 6: CommuteViewModel — Provider Selection and Mood Update

**Files:**
- Modify: `TrafficMenubar/ViewModels/CommuteViewModel.swift`

- [ ] **Step 1: Add cached provider with settings observation**

Replace the `provider` property and update `init` to cache the provider and observe settings changes:

Replace `private(set) var provider: TrafficProvider` with:

```swift
private(set) var provider: TrafficProvider
private var settingsCancellable: AnyCancellable?
```

At the end of `init(...)`, add settings observation (after assigning the three properties):

```swift
self.provider = Self.makeProvider(for: settings)
settingsCancellable = settings.$mapboxKeySource
    .combineLatest(settings.$mapboxAPIKey)
    .sink { [weak self] _, _ in
        guard let self else { return }
        self.provider = Self.makeProvider(for: self.settings)
    }
```

Add the factory method:

```swift
private static func makeProvider(for settings: SettingsStore) -> TrafficProvider {
    if let key = settings.effectiveMapboxKey {
        return MapboxDirectionsProvider(apiKey: key)
    }
    return MapKitProvider()
}
```

- [ ] **Step 2: Update mood computed property**

Replace the existing `mood` computed property:

```swift
var mood: TrafficMood {
    guard let route = fastestRoute else { return .unknown }
    if let congestion = route.segmentCongestion, !congestion.isEmpty {
        return TrafficMood(segmentCongestion: congestion)
    }
    return TrafficMood(delayMinutes: route.delayMinutes, hasIncidents: route.hasIncidents)
}
```

This requires the new `TrafficMood` initializer from Task 7. If building incrementally, this step can be deferred to after Task 7 and temporarily keep the existing mood logic.

- [ ] **Step 3: Update menuBarText to use the mood property**

Replace the `menuBarText` computed property so it uses the shared `mood` property (which is now congestion-aware) instead of constructing its own `TrafficMood`:

```swift
var menuBarText: String {
    guard let route = fastestRoute else {
        return "--"
    }
    let minutes = route.travelTimeMinutes
    return "\(minutes)m\(mood.menuBarSuffix)"
}
```

- [ ] **Step 4: Update disableDevMode to use makeProvider**

Change `disableDevMode()` to:

```swift
func disableDevMode() {
    provider = Self.makeProvider(for: settings)
    isDevMode = false
    startPolling()
}
```

- [ ] **Step 5: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (may need Task 7 first for the mood initializer — if so, skip this build check and verify after Task 7)

- [ ] **Step 6: Commit**

```bash
git add TrafficMenubar/ViewModels/CommuteViewModel.swift
git commit -m "feat: add provider selection based on Mapbox settings and congestion-aware mood"
```

---

### Task 7: DesignSystem — TrafficMood Congestion Initializer and Color Helpers

**Files:**
- Modify: `TrafficMenubar/Views/DesignSystem.swift`

- [ ] **Step 1: Add congestion-based TrafficMood initializer**

Add a new initializer to the `TrafficMood` enum, after the existing `init(delayMinutes:hasIncidents:)`:

```swift
init(segmentCongestion: [CongestionLevel]) {
    guard !segmentCongestion.isEmpty else {
        self = .unknown
        return
    }
    let total = segmentCongestion.count
    let severeOrHeavy = segmentCongestion.filter { $0 == .severe || $0 == .heavy }.count
    let ratio = Double(severeOrHeavy) / Double(total)

    if ratio > 0.3 {
        self = .heavy
    } else if ratio > 0.1 {
        self = .moderate
    } else {
        self = .clear
    }
}
```

- [ ] **Step 2: Add CongestionLevel color helper**

Add as an extension at the bottom of the file (or within the `Design` enum):

```swift
extension CongestionLevel {
    var color: Color {
        switch self {
        case .low:      return Color(red: 0.29, green: 0.68, blue: 0.50) // #4DAD80
        case .moderate: return Color(red: 0.98, green: 0.75, blue: 0.14) // #FDC21C
        case .heavy:    return Color(red: 0.97, green: 0.44, blue: 0.44) // #F76F6F
        case .severe:   return Color(red: 0.83, green: 0.18, blue: 0.18) // #D32F2F
        case .unknown:  return Color.gray.opacity(0.5)
        }
    }

    var nsColor: NSColor {
        switch self {
        case .low:      return NSColor(red: 0.29, green: 0.68, blue: 0.50, alpha: 0.9)
        case .moderate: return NSColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 0.9)
        case .heavy:    return NSColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 0.9)
        case .severe:   return NSColor(red: 0.83, green: 0.18, blue: 0.18, alpha: 0.9)
        case .unknown:  return NSColor.gray.withAlphaComponent(0.5)
        }
    }
}
```

Note: add `import AppKit` at the top of DesignSystem.swift if not already present (needed for `NSColor`).

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/DesignSystem.swift
git commit -m "feat: add congestion-based mood initializer and CongestionLevel color helpers"
```

---

### Task 8: StylizedRouteLineView — Congestion-Colored Segments

**Files:**
- Modify: `TrafficMenubar/Views/StylizedRouteLineView.swift`

- [ ] **Step 1: Add congestion gradient line builder**

Add a new `@ViewBuilder` property alongside the existing `gradientLine`:

```swift
@ViewBuilder
private var congestionGradientLine: some View {
    if let congestion = route.segmentCongestion, !congestion.isEmpty {
        let stops = congestion.enumerated().map { index, level in
            Gradient.Stop(
                color: level.color,
                location: CGFloat(index) / CGFloat(max(congestion.count - 1, 1))
            )
        }
        RoundedRectangle(cornerRadius: 2)
            .fill(LinearGradient(
                stops: stops,
                startPoint: .leading,
                endPoint: .trailing
            ))
    }
}
```

- [ ] **Step 2: Update the body to use congestion gradient when available**

In the `body`, replace the two references to `gradientLine` (the glow and the main line) with a conditional:

Replace the `ZStack(alignment: .leading)` content to check for congestion data:

```swift
ZStack(alignment: .leading) {
    let hasCongestion = route.segmentCongestion != nil && !(route.segmentCongestion?.isEmpty ?? true)

    if isFastest {
        Group {
            if hasCongestion { congestionGradientLine } else { gradientLine }
        }
        .frame(height: lineThickness + 6)
        .opacity(0.08)
        .blur(radius: 2)
    }

    Group {
        if hasCongestion { congestionGradientLine } else { gradientLine }
    }
    .frame(height: lineThickness)
    .mask(
        Rectangle()
            .frame(width: geo.size.width * drawProgress)
            .frame(maxWidth: .infinity, alignment: .leading)
    )

    if route.hasIncidents {
        incidentDiamond
            .position(x: geo.size.width * 0.45, y: geo.size.height / 2)
            .opacity(Double(drawProgress))
    }
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/StylizedRouteLineView.swift
git commit -m "feat: add per-segment congestion coloring to stylized route line"
```

---

### Task 9: MapPreviewView — Congestion-Colored Polylines

**Files:**
- Modify: `TrafficMenubar/Views/MapPreviewView.swift`

- [ ] **Step 1: Extend TaggedPolyline with congestion color**

Add a `congestionColor` property to `TaggedPolyline`:

```swift
class TaggedPolyline: MKPolyline {
    var isPrimary: Bool = true
    var congestionColor: NSColor?
}
```

- [ ] **Step 2: Update updateNSView to create congestion segments for primary route**

Replace the primary route overlay section (the `if primaryRouteIndex < routes.count` block) with congestion-aware rendering:

```swift
// Add primary route on top
if primaryRouteIndex < routes.count {
    let primary = routes[primaryRouteIndex]

    if let congestion = primary.segmentCongestion, congestion.count > 1 {
        // Draw congestion-colored segments
        let coords = primary.polylineCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let segmentCount = min(congestion.count, coords.count - 1)
        for i in 0..<segmentCount {
            var segCoords = [coords[i], coords[i + 1]]
            let polyline = TaggedPolyline(coordinates: &segCoords, count: 2)
            polyline.isPrimary = true
            polyline.congestionColor = congestion[i].nsColor
            mapView.addOverlay(polyline)
        }

        // Fit to full route bounds
        let allCoords = coords
        let polyline = MKPolyline(coordinates: allCoords, count: allCoords.count)
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
            animated: false
        )
    } else {
        // Fallback: solid green (existing behavior)
        let coordinates = primary.polylineCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let polyline = TaggedPolyline(coordinates: coordinates, count: coordinates.count)
        polyline.isPrimary = true
        mapView.addOverlay(polyline)

        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
            animated: false
        )
    }
}
```

- [ ] **Step 3: Update the renderer to use congestion color**

In the Coordinator's `rendererFor overlay` method, update the primary route branch:

```swift
if polyline.isPrimary {
    if let congestionColor = polyline.congestionColor {
        renderer.strokeColor = congestionColor
    } else {
        renderer.strokeColor = NSColor(red: 0.29, green: 0.68, blue: 0.50, alpha: 0.9)
    }
    renderer.lineWidth = 4
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TrafficMenubar/Views/MapPreviewView.swift
git commit -m "feat: add congestion-colored polyline segments to map preview"
```

---

### Task 10: PreferencesView — Premium Traffic Provider UI

**Files:**
- Modify: `TrafficMenubar/Views/PreferencesView.swift`

This is the largest UI change. The existing "TRAFFIC PROVIDER" section (lines 358-371) gets replaced with the three-state premium teaser/BYOK/active UI.

- [ ] **Step 1: Add state variables for the premium UI**

Add to the existing `@State` variables at the top of `PreferencesView`:

```swift
@State private var showingBYOKInput = false
@State private var byokKeyInput = ""
```

- [ ] **Step 2: Replace the Traffic Provider section in generalTab**

Replace the existing "TRAFFIC PROVIDER" `VStack` (the one containing "Apple Maps" and "More coming soon") with the three-state UI.

Remove:
```swift
// Traffic Provider
VStack(alignment: .leading, spacing: 8) {
    Text("TRAFFIC PROVIDER")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
        .tracking(0.5)
    HStack {
        Text("Apple Maps")
            .font(.system(size: 13, design: .rounded))
            .foregroundColor(isDark ? .white.opacity(0.7) : .primary)
        Spacer()
        Text("More coming soon")
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(isDark ? .white.opacity(0.25) : .secondary.opacity(0.6))
    }
}
```

Replace with:
```swift
// Traffic Provider
VStack(alignment: .leading, spacing: 8) {
    Text("TRAFFIC PROVIDER")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
        .tracking(0.5)

    trafficProviderContent
}
```

- [ ] **Step 3: Add the trafficProviderContent view builder**

Add as a new computed property in `PreferencesView`:

```swift
@ViewBuilder
private var trafficProviderContent: some View {
    let isMapboxActive = settings.effectiveMapboxKey != nil

    // Apple Maps row
    HStack {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.78, blue: 0.35), Color(red: 0.19, green: 0.82, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 20, height: 20)
                .overlay(Circle().fill(.white).frame(width: 6, height: 6))
            Text("Apple Maps")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(isDark ? .white.opacity(isMapboxActive ? 0.4 : 0.85) : (isMapboxActive ? .secondary : .primary))
        }
        Spacer()
        if !isMapboxActive {
            Text("✓ Active")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(TrafficMood.clear.darkAccentColor)
        }
    }
    .opacity(isMapboxActive ? 0.45 : 1.0)

    // Mapbox card
    if isMapboxActive {
        mapboxActiveCard
    } else if showingBYOKInput {
        mapboxBYOKInputCard
    } else {
        mapboxTeaserCard
    }
}
```

- [ ] **Step 4: Add the mapboxTeaserCard (State 1)**

```swift
@ViewBuilder
private var mapboxTeaserCard: some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(red: 0.65, green: 0.55, blue: 0.98), Color(red: 0.51, green: 0.55, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 20, height: 20)
                .overlay(Image(systemName: "lock.fill").font(.system(size: 8)).foregroundColor(.white))
            Text("Mapbox Premium")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(isDark ? .white.opacity(0.95) : .primary)
        }

        Text("Real-time congestion data · Per-segment traffic colors · Incident alerts · Accurate free-flow ETAs")
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(isDark ? .white.opacity(0.6) : .secondary)
            .lineSpacing(2)

        HStack(spacing: 8) {
            Button("I have a Mapbox key") {
                showingBYOKInput = true
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(Color(red: 0.77, green: 0.71, blue: 0.99))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.15))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.3), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .buttonStyle(.plain)

            Button("Get Premium Access") {}
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(isDark ? .white.opacity(0.6) : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .buttonStyle(.plain)
        }
    }
    .padding(14)
    .background(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.08))
    .overlay(
        VStack {
            LinearGradient(colors: [Color(red: 0.65, green: 0.55, blue: 0.98), Color(red: 0.51, green: 0.55, blue: 0.97)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
            Spacer()
        }
    )
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.2), lineWidth: 1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

- [ ] **Step 5: Add the mapboxBYOKInputCard (State 2)**

```swift
@ViewBuilder
private var mapboxBYOKInputCard: some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(red: 0.65, green: 0.55, blue: 0.98), Color(red: 0.51, green: 0.55, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 20, height: 20)
                .overlay(Image(systemName: "key.fill").font(.system(size: 8)).foregroundColor(.white))
            Text("Enter Mapbox API Key")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(isDark ? .white.opacity(0.95) : .primary)
        }

        TextField("pk.eyJ1IjoiZXhhbXBsZSIsImEiOiJja...", text: $byokKeyInput)
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(isDark ? .white.opacity(0.7) : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isDark ? Color.black.opacity(0.4) : Color.black.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))

        HStack(spacing: 10) {
            Button("Save Key") {
                guard !byokKeyInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                settings.setMapboxKey(byokKeyInput.trimmingCharacters(in: .whitespaces), source: "byok")
                byokKeyInput = ""
                showingBYOKInput = false
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(LinearGradient(colors: [Color(red: 0.65, green: 0.55, blue: 0.98), Color(red: 0.51, green: 0.55, blue: 0.97)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .buttonStyle(.plain)

            Button("Cancel") {
                byokKeyInput = ""
                showingBYOKInput = false
            }
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(isDark ? .white.opacity(0.55) : .secondary)
            .buttonStyle(.plain)
        }

        Text("Get a free key at mapbox.com/account · Includes 100k directions requests/month")
            .font(.system(size: 10, design: .rounded))
            .foregroundColor(isDark ? .white.opacity(0.45) : .secondary.opacity(0.7))
    }
    .padding(14)
    .background(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.08))
    .overlay(
        VStack {
            LinearGradient(colors: [Color(red: 0.65, green: 0.55, blue: 0.98), Color(red: 0.51, green: 0.55, blue: 0.97)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
            Spacer()
        }
    )
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.25), lineWidth: 1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

- [ ] **Step 6: Add the mapboxActiveCard (State 3)**

```swift
@ViewBuilder
private var mapboxActiveCard: some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Color(red: 0.65, green: 0.55, blue: 0.98), Color(red: 0.51, green: 0.55, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 20, height: 20)
                    .overlay(Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundColor(.white))
                Text("Mapbox Premium")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.95) : .primary)
            }
            Spacer()
            HStack(spacing: 8) {
                Text(settings.mapboxKeySource == "byok" ? "BYOK" : "PREMIUM")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundColor(Color(red: 0.77, green: 0.71, blue: 0.99))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.25), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("✓ Active")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(TrafficMood.clear.darkAccentColor)
            }
        }

        // Masked key
        let maskedKey = String(settings.mapboxAPIKey.prefix(4)) + " ••••••••••••••••"
        Text(maskedKey)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isDark ? Color.black.opacity(0.25) : Color.black.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 4))

        HStack(spacing: 12) {
            Button("Remove Key") {
                settings.clearMapboxKey()
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(Color(red: 0.99, green: 0.65, blue: 0.65))
            .buttonStyle(.plain)

            Text("Falls back to Apple Maps")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(isDark ? .white.opacity(0.4) : .secondary.opacity(0.6))
        }
    }
    .padding(14)
    .background(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.08))
    .overlay(
        VStack {
            LinearGradient(colors: [TrafficMood.clear.darkAccentColor, Color(red: 0.19, green: 0.82, blue: 0.35)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
            Spacer()
        }
    )
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.3), lineWidth: 1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

- [ ] **Step 7: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add TrafficMenubar/Views/PreferencesView.swift
git commit -m "feat: add three-state premium Mapbox UI to preferences"
```

---

### Task 11: MockTrafficProvider — Congestion Data Support

**Files:**
- Modify: `TrafficMenubar/Providers/MockTrafficProvider.swift`

Add the ability to generate mock congestion data for dev testing.

- [ ] **Step 1: Add congestion toggle and generation**

Add a new published property:

```swift
@Published var includeCongestion: Bool = false
```

Add a helper to generate sample congestion data:

```swift
private func generateCongestion(count: Int) -> [CongestionLevel] {
    let levels: [CongestionLevel] = [.low, .low, .low, .moderate, .moderate, .heavy, .severe]
    return (0..<count).map { _ in levels.randomElement() ?? .low }
}
```

- [ ] **Step 2: Update Route construction to pass congestion**

In `buildRoutes()`, update the primary route construction:

```swift
let primaryRoute = Route(
    name: "via I-285 S",
    travelTime: travelTime,
    normalTravelTime: normalTime,
    distance: 20_000,
    polylineCoordinates: Self.samplePolyline,
    mkPolyline: nil,
    advisoryNotices: includeIncidents ? ["Construction on main route"] : [],
    segmentCongestion: includeCongestion ? generateCongestion(count: Self.samplePolyline.count - 1) : nil
)
```

And each alternate route:

```swift
let altRoute = Route(
    name: altNames[i],
    travelTime: travelTime + altDelay * 60,
    normalTravelTime: normalTime + altDelay * 60,
    distance: 20_000 + Double((i + 1) * 2000),
    polylineCoordinates: Self.samplePolyline,
    mkPolyline: nil,
    advisoryNotices: [],
    segmentCongestion: includeCongestion ? generateCongestion(count: Self.samplePolyline.count - 1) : nil
)
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Providers/MockTrafficProvider.swift
git commit -m "feat: add mock congestion data support for dev testing"
```

---

### Task 12: DeveloperSettingsView — Congestion Toggle

**Files:**
- Modify: `TrafficMenubar/Views/DeveloperSettingsView.swift`

- [ ] **Step 1: Add congestion toggle to the Route Data section**

In the `routeDataSection`, add after the existing content (after the delay/mood HStack):

```swift
Toggle("Include congestion data (Mapbox-style)", isOn: $mockProvider.includeCongestion)
    .font(.system(size: 12))
    .foregroundColor(primaryText)
    .tint(.orange)
```

- [ ] **Step 2: Add onChange observer for the new toggle**

In the `.onChange` modifiers on the body's ScrollView, add:

```swift
.onChange(of: mockProvider.includeCongestion) { _ in applyState() }
```

- [ ] **Step 3: Update quick presets to include congestion option**

In the "Heavy + incidents" preset, add `mockProvider.includeCongestion = true`:

```swift
("🌧 Heavy + incidents", {
    mockProvider.travelTimeMinutes = 55
    mockProvider.normalTimeMinutes = 25
    mockProvider.includeIncidents = true
    mockProvider.includeCongestion = true
    mockProvider.incidentCount = 2
    mockProvider.maxSeverity = .severe
    forcedState = .normal
    forcedFailures = 0
}),
```

And in the "Clear roads" preset, add `mockProvider.includeCongestion = false`.

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TrafficMenubar/Views/DeveloperSettingsView.swift
git commit -m "feat: add congestion data toggle to developer settings"
```

---

### Task 13: Integration Verification

- [ ] **Step 1: Full build**

Run: `xcodebuild build -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED with no warnings related to our changes.

- [ ] **Step 2: Manual smoke test checklist**

Launch the app and verify:
1. Free tier works unchanged — Apple Maps routing, stylized line with delay-based gradient, mood badge
2. Open Preferences → General → Traffic Provider section shows teaser card
3. Click "I have a Mapbox key" → input field appears
4. Paste a key → click Save → card switches to active state with masked key
5. Click Remove Key → reverts to Apple Maps with teaser
6. Enable Developer Mode → toggle "Include congestion data" → verify stylized route line shows multi-colored segments
7. Verify map preview shows colored segments when congestion data is present

- [ ] **Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: integration fixes for Mapbox premium feature"
```
