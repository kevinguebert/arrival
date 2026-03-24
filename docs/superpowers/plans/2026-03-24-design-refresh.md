# Design Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Traffic Menubar popover with adaptive dark/light theme, Signal/Pulse icons, multi-route display, rotating mood copy, and purposeful animations.

**Architecture:** Bottom-up — data model first, then design system, then views. Each task produces a compilable, testable change. The existing single-route architecture is replaced with multi-route throughout the stack: model → provider → view model → views.

**Tech Stack:** Swift, SwiftUI, MapKit, macOS 13+

**Spec:** `docs/superpowers/specs/2026-03-24-design-refresh-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `TrafficMenubar/Models/RouteResult.swift` | Modify | Add `Route` struct, update `RouteResult` to hold `[Route]` |
| `TrafficMenubar/Providers/TrafficProvider.swift` | Modify | Rename protocol method to `fetchRoutes`, return new `RouteResult` |
| `TrafficMenubar/Providers/MapKitProvider.swift` | Modify | Request alternate routes, build `[Route]` array |
| `TrafficMenubar/Providers/MockTrafficProvider.swift` | Modify | Generate mock multi-route data |
| `TrafficMenubar/ViewModels/CommuteViewModel.swift` | Modify | Store `RouteResult` with `[Route]`, update mood/menubar logic |
| `TrafficMenubar/Views/DesignSystem.swift` | Modify | New colors, mood phrases, pulse params, adaptive theme, remove emoji |
| `TrafficMenubar/Views/PopoverView.swift` | Rewrite | Adaptive theme, new layout with route list, pulse badge, atmospheric glow |
| `TrafficMenubar/Views/RouteListView.swift` | Create | Route list card with stylized lines per route |
| `TrafficMenubar/Views/StylizedRouteLineView.swift` | Create | Reusable gradient route line with animated draw-in |
| `TrafficMenubar/Views/PulseDotView.swift` | Create | Animated signal/pulse orb with mood-driven breathing |
| `TrafficMenubar/Views/ExpandableMapView.swift` | Create | Tap-to-expand map with multi-route overlays |
| `TrafficMenubar/Views/MapPreviewView.swift` | Modify | Support multiple route overlays, highlight primary |
| `TrafficMenubar/Views/IncidentBannerView.swift` | Remove | Replaced by inline incident display in RouteListView |
| `TrafficMenubar/Views/QuickSettingsView.swift` | Modify | Minor theme alignment |
| `TrafficMenubar/ViewModels/DevDesignOverrides.swift` | Modify | Add multi-route mock overrides |
| `TrafficMenubar/TrafficMenubarApp.swift` | Modify | Update menubar label to use SF Symbols |

---

## Task 1: Update Data Model — Route struct and multi-route RouteResult

**Files:**
- Modify: `TrafficMenubar/Models/RouteResult.swift`

- [ ] **Step 1: Add the new `Route` struct above `RouteResult`**

```swift
import MapKit

struct Route: Identifiable {
    let id = UUID()
    let name: String
    let travelTime: TimeInterval
    let normalTravelTime: TimeInterval
    let distance: CLLocationDistance
    let polylineCoordinates: [Coordinate]
    let mkPolyline: MKPolyline?
    let advisoryNotices: [String]

    var travelTimeMinutes: Int { Int(travelTime / 60) }
    var delayMinutes: Int { max(0, Int((travelTime - normalTravelTime) / 60)) }
    var eta: Date { Date().addingTimeInterval(travelTime) }
    var hasIncidents: Bool { !advisoryNotices.isEmpty }
}
```

- [ ] **Step 2: Replace the existing `RouteResult` struct**

Replace the entire `RouteResult` struct with:

```swift
struct RouteResult {
    let routes: [Route]
    let incidents: [TrafficIncident]
    let fetchedAt: Date

    var fastestRoute: Route? { routes.first }
    var hasAlternates: Bool { routes.count > 1 }

    /// Smart collapse: true when all routes are within 2 minutes of the fastest
    var shouldCollapse: Bool {
        guard let fastest = fastestRoute else { return true }
        return routes.allSatisfy { abs($0.travelTimeMinutes - fastest.travelTimeMinutes) <= 2 }
    }
}
```

- [ ] **Step 3: Add `import MapKit` at the top of the file if not already present**

The file currently imports only Foundation. Add `import MapKit` for `MKPolyline` and `CLLocationDistance`.

- [ ] **Step 4: Verify the file compiles (it won't yet — that's expected)**

The project won't compile because `TrafficProvider`, `MapKitProvider`, `MockTrafficProvider`, `CommuteViewModel`, and views all reference the old `RouteResult` shape. That's fine — we'll fix each in subsequent tasks.

- [ ] **Step 5: Commit**

```bash
git add TrafficMenubar/Models/RouteResult.swift
git commit -m "feat: add Route struct and update RouteResult for multi-route support"
```

---

## Task 2: Update TrafficProvider Protocol

**Files:**
- Modify: `TrafficMenubar/Providers/TrafficProvider.swift`

- [ ] **Step 1: Rename the protocol method**

Change:
```swift
func fetchRoute(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult
```
To:
```swift
func fetchRoutes(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult
```

- [ ] **Step 2: Commit**

```bash
git add TrafficMenubar/Providers/TrafficProvider.swift
git commit -m "feat: rename TrafficProvider.fetchRoute to fetchRoutes"
```

---

## Task 3: Update MapKitProvider for Multi-Route

**Files:**
- Modify: `TrafficMenubar/Providers/MapKitProvider.swift`

- [ ] **Step 1: Enable alternate routes and build `[Route]` array**

Replace the entire `fetchRoute` method with `fetchRoutes`:

```swift
func fetchRoutes(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(
        coordinate: CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
    ))
    request.destination = MKMapItem(placemark: MKPlacemark(
        coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
    ))
    request.transportType = .automobile
    request.departureDate = Date()
    request.requestsAlternateRoutes = true

    let directions = MKDirections(request: request)

    let response: MKDirections.Response
    do {
        response = try await directions.calculate()
    } catch {
        throw TrafficProviderError.networkError(error)
    }

    guard !response.routes.isEmpty else {
        throw TrafficProviderError.noRouteFound
    }

    let sortedRoutes = response.routes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
    let routes = Array(sortedRoutes.prefix(3)).map { mkRoute in
        Route(
            name: mkRoute.name,
            travelTime: mkRoute.expectedTravelTime,
            normalTravelTime: estimateNormalTravelTime(distanceMeters: mkRoute.distance),
            distance: mkRoute.distance,
            polylineCoordinates: extractPolyline(from: mkRoute.polyline),
            mkPolyline: mkRoute.polyline,
            advisoryNotices: mkRoute.advisoryNotices
        )
    }

    return RouteResult(
        routes: routes,
        incidents: [],
        fetchedAt: Date()
    )
}
```

- [ ] **Step 2: Keep existing helper methods (`estimateNormalTravelTime`, `extractPolyline`) unchanged**

They work as-is.

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Providers/MapKitProvider.swift
git commit -m "feat: update MapKitProvider to fetch multiple routes"
```

---

## Task 4: Update MockTrafficProvider for Multi-Route

**Files:**
- Modify: `TrafficMenubar/Providers/MockTrafficProvider.swift`

- [ ] **Step 1: Add published properties for alternate route control**

Add below the existing `@Published` properties:

```swift
@Published var alternateRouteCount: Int = 2
@Published var alternateDelayMinutes: Double = 8
```

- [ ] **Step 2: Replace `fetchRoute` with `fetchRoutes` and update `buildRoute` to `buildRoutes`**

```swift
func fetchRoutes(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
    buildRoutes()
}

func buildRoutes() -> RouteResult {
    let travelTime = travelTimeMinutes * 60
    let normalTime = normalTimeMinutes * 60

    let primaryRoute = Route(
        name: "via I-285 S",
        travelTime: travelTime,
        normalTravelTime: normalTime,
        distance: 20_000,
        polylineCoordinates: Self.samplePolyline,
        mkPolyline: nil,
        advisoryNotices: includeIncidents ? ["Construction on main route"] : []
    )

    var routes = [primaryRoute]

    let altNames = ["via Peachtree Rd", "via GA-400 N"]
    for i in 0..<min(alternateRouteCount, altNames.count) {
        let altDelay = alternateDelayMinutes * Double(i + 1)
        let altRoute = Route(
            name: altNames[i],
            travelTime: travelTime + altDelay * 60,
            normalTravelTime: normalTime + altDelay * 60,
            distance: 20_000 + Double((i + 1) * 2000),
            polylineCoordinates: Self.samplePolyline,
            mkPolyline: nil,
            advisoryNotices: []
        )
        routes.append(altRoute)
    }

    return RouteResult(
        routes: routes,
        incidents: includeIncidents ? generateIncidents() : [],
        fetchedAt: Date()
    )
}
```

- [ ] **Step 3: Remove old `buildRoute()` method (singular)**

The old method is replaced by `buildRoutes()`. Find all references and update them.

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Providers/MockTrafficProvider.swift
git commit -m "feat: update MockTrafficProvider for multi-route mock data"
```

---

## Task 5: Update CommuteViewModel

**Files:**
- Modify: `TrafficMenubar/ViewModels/CommuteViewModel.swift`

- [ ] **Step 1: Replace `currentRoute: RouteResult?` with `currentResult: RouteResult?`**

Change the published property:
```swift
@Published var currentResult: RouteResult?
```

- [ ] **Step 2: Add convenience computed properties**

```swift
var fastestRoute: Route? { currentResult?.fastestRoute }

var mood: TrafficMood {
    guard let route = fastestRoute else { return .unknown }
    return TrafficMood(delayMinutes: route.delayMinutes, hasIncidents: route.hasIncidents)
}
```

- [ ] **Step 3: Update `menuBarText`**

```swift
var menuBarText: String {
    guard let route = fastestRoute else {
        return "--"
    }
    let minutes = route.travelTimeMinutes
    let mood = TrafficMood(delayMinutes: route.delayMinutes, hasIncidents: route.hasIncidents)
    return "\(minutes)m\(mood.menuBarSuffix)"
}
```

- [ ] **Step 4: Update `fetchRoute()` to call `fetchRoutes`**

Rename internal method and update the call:
```swift
private func fetchRoute() async {
    guard settings.isConfigured,
          let home = settings.homeCoordinate,
          let work = settings.workCoordinate else {
        return
    }

    locationManager.requestLocation()
    let detectedDirection = resolveDirection(home: home, work: work)
    direction = detectedDirection

    let origin: Coordinate
    let destination: Coordinate
    switch detectedDirection {
    case .toWork:
        origin = home
        destination = work
    case .toHome:
        origin = work
        destination = home
    }

    isLoading = currentResult == nil
    do {
        let result = try await provider.fetchRoutes(from: origin, to: destination)
        currentResult = result
        consecutiveFailures = 0
        lastUpdated = Date()
    } catch {
        consecutiveFailures += 1
    }
    isLoading = false
}
```

- [ ] **Step 5: Update `updateFromMock` signature**

```swift
func updateFromMock(result: RouteResult?, direction: CommuteDirection, consecutiveFailures: Int, isLoading: Bool) {
    self.currentResult = result
    self.direction = direction
    self.consecutiveFailures = consecutiveFailures
    self.isLoading = isLoading
    self.lastUpdated = result != nil ? Date() : nil
}
```

- [ ] **Step 6: Commit**

```bash
git add TrafficMenubar/ViewModels/CommuteViewModel.swift
git commit -m "feat: update CommuteViewModel for multi-route RouteResult"
```

---

## Task 6: Update DesignSystem — Colors, Mood Phrases, Pulse Params

**Files:**
- Modify: `TrafficMenubar/Views/DesignSystem.swift`

- [ ] **Step 1: Add adaptive color system to `TrafficMood`**

Add these computed properties to the `TrafficMood` enum, below the existing `accentColor`:

```swift
/// Accent color for dark mode (brighter, more vivid)
var darkAccentColor: Color {
    switch self {
    case .clear:    return Color(red: 0.29, green: 0.68, blue: 0.50)  // #4ade80
    case .moderate: return Color(red: 0.98, green: 0.75, blue: 0.14)  // #fbbf24
    case .heavy:    return Color(red: 0.97, green: 0.44, blue: 0.44)  // #f87171
    case .unknown:  return Color(red: 0.58, green: 0.64, blue: 0.72)  // #94a3b8
    }
}

/// Accent color for light mode text (darker for readability)
var lightTextColor: Color {
    switch self {
    case .clear:    return Color(red: 0.09, green: 0.64, blue: 0.29)  // #16a34a
    case .moderate: return Color(red: 0.85, green: 0.47, blue: 0.02)  // #d97706
    case .heavy:    return Color(red: 0.86, green: 0.15, blue: 0.15)  // #dc2626
    case .unknown:  return Color(red: 0.39, green: 0.45, blue: 0.55)  // #64748b
    }
}

/// Gradient end color for accent stripe
var accentGradientEnd: Color {
    switch self {
    case .clear:    return Color(red: 0.13, green: 0.77, blue: 0.37)  // #22c55e
    case .moderate: return Color(red: 0.96, green: 0.62, blue: 0.04)  // #f59e0b
    case .heavy:    return Color(red: 0.94, green: 0.27, blue: 0.27)  // #ef4444
    case .unknown:  return Color(red: 0.39, green: 0.45, blue: 0.55)  // #64748b
    }
}
```

- [ ] **Step 2: Replace `moodEmoji` and `moodPhrase` with rotating phrases**

Remove `moodEmoji` and `moodPhrase`. Add:

```swift
var moodPhrases: [String] {
    switch self {
    case .clear:
        return [
            "Smooth sailing", "Open road vibes", "Not a car in sight",
            "Cruising along", "Highway's all yours", "Ghost town out there",
            "Breezing through", "Like a Sunday drive", "Green lights all day",
            "Wind in your hair", "The road is your oyster"
        ]
    case .moderate:
        return [
            "A bit sluggish", "Dragging a little", "Could be worse",
            "Patience, grasshopper", "Slow and steady", "Taking its sweet time",
            "Not great, not terrible", "Hitting some molasses", "Rush hour vibes",
            "The scenic pace", "Everyone had the same idea"
        ]
    case .heavy:
        return [
            "Buckle up, buttercup", "Gonna be a minute", "Pour another coffee",
            "Yikes on bikes", "It's a parking lot", "Send snacks",
            "Abandon all hope", "Netflix in the car time", "Bring a podcast",
            "Might wanna leave early", "RIP your ETA"
        ]
    case .unknown:
        return [
            "Scouting the roads...", "Checking the vibes...",
            "Asking the traffic gods...", "Hold tight...",
            "Poking around out there...", "Consulting the oracle...",
            "Summoning traffic data...", "Warming up the satellites...",
            "One sec, peeking outside...", "Phoning a friend..."
        ]
    }
}

func randomPhrase() -> String {
    moodPhrases.randomElement() ?? moodPhrases[0]
}
```

- [ ] **Step 3: Update `menuBarSuffix` to use SF Symbol names**

```swift
var menuBarSuffix: String {
    switch self {
    case .clear:    return ""
    case .moderate: return " ●"
    case .heavy:    return " ▲"
    case .unknown:  return ""
    }
}
```

- [ ] **Step 4: Add pulse animation parameters**

```swift
var pulseDuration: Double {
    switch self {
    case .clear:    return 3.0
    case .moderate: return 2.0
    case .heavy:    return 1.2
    case .unknown:  return 2.5
    }
}

var pulseScale: CGFloat {
    switch self {
    case .clear:    return 1.08
    case .moderate: return 1.12
    case .heavy:    return 1.15
    case .unknown:  return 1.0  // uses opacity instead
    }
}
```

- [ ] **Step 5: Add dark/light background colors to `Design` enum**

```swift
// Adaptive backgrounds
static let darkBgTop = Color(red: 0.059, green: 0.071, blue: 0.098)      // #0f1219
static let darkBgBottom = Color(red: 0.086, green: 0.106, blue: 0.149)    // #161b26
static let lightBgTop = Color.white
static let lightBgBottom = Color(red: 0.973, green: 0.980, blue: 0.984)   // #f8fafb
static let darkText = Color(red: 0.102, green: 0.102, blue: 0.180)        // #1a1a2e

// Route list
static let routeCardCornerRadius: CGFloat = 10
static let moodBadgeCornerRadius: CGFloat = 20
static let routeNameSize: CGFloat = 12
static let routeTimeSize: CGFloat = 14

static func routeNameFont(scale: CGFloat = 1.0, isFastest: Bool = true) -> Font {
    .system(size: routeNameSize * scale, weight: isFastest ? .semibold : .medium, design: .rounded)
}
static func routeTimeFont(scale: CGFloat = 1.0, isFastest: Bool = true) -> Font {
    .system(size: routeTimeSize * scale, weight: isFastest ? .bold : .semibold, design: .rounded)
}
```

- [ ] **Step 6: Update `EmptyState` with rotating error phrases**

```swift
enum EmptyState {
    static let noRoute = (
        icon: "car.side",
        title: "Where to?",
        subtitle: "Set up your addresses in Preferences to get started."
    )

    static let loading = (
        icon: "binoculars",
        title: "Scouting the roads...",
        subtitle: "Hang tight, checking traffic for you."
    )

    static let errorPhrases = [
        "Lost signal",
        "Can't reach the traffic gods",
        "The internet took a detour",
        "Signals crossed, trying again"
    ]

    static let error = (
        icon: "cloud.bolt",
        title: "Lost signal",
        subtitle: "Will retry automatically."
    )

    static let noRoutesFound = (
        icon: "map",
        title: "Hmm, no routes found",
        subtitle: "MapKit shrugged. Try different addresses?"
    )
}
```

- [ ] **Step 7: Commit**

```bash
git add TrafficMenubar/Views/DesignSystem.swift
git commit -m "feat: update DesignSystem with adaptive colors, mood phrases, pulse params"
```

---

## Task 7: Create PulseDotView

**Files:**
- Create: `TrafficMenubar/Views/PulseDotView.swift`

- [ ] **Step 1: Create the animated pulse dot component**

```swift
import SwiftUI

struct PulseDotView: View {
    let mood: TrafficMood
    let size: CGFloat

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(mood.darkAccentColor)
            .frame(width: size, height: size)
            .shadow(color: mood.darkAccentColor.opacity(glowOpacity), radius: glowRadius)
            .scaleEffect(isAnimating ? mood.pulseScale : 1.0)
            .opacity(mood == .unknown ? (isAnimating ? 1.0 : 0.4) : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: mood.pulseDuration)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
            .onChange(of: mood) { newMood in
                isAnimating = false
                withAnimation(
                    .easeInOut(duration: newMood.pulseDuration)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }

    private var glowOpacity: Double {
        switch mood {
        case .clear:    return 0.5
        case .moderate: return 0.5
        case .heavy:    return 0.6
        case .unknown:  return 0.3
        }
    }

    private var glowRadius: CGFloat {
        switch mood {
        case .clear:    return 4
        case .moderate: return 5
        case .heavy:    return 6
        case .unknown:  return 3
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TrafficMenubar/Views/PulseDotView.swift
git commit -m "feat: add PulseDotView with mood-driven breathing animation"
```

---

## Task 8: Create StylizedRouteLineView

**Files:**
- Create: `TrafficMenubar/Views/StylizedRouteLineView.swift`

- [ ] **Step 1: Create the animated gradient route line**

```swift
import SwiftUI

struct StylizedRouteLineView: View {
    let route: Route
    let fastestTravelTime: TimeInterval
    let isFastest: Bool
    @Environment(\.colorScheme) private var colorScheme

    @State private var drawProgress: CGFloat = 0

    private var lineThickness: CGFloat { isFastest ? 3 : 2 }
    private var dotSize: CGFloat { isFastest ? 10 : 7 }
    private var overallOpacity: Double { isFastest ? 1.0 : 0.5 }

    var body: some View {
        HStack(spacing: 0) {
            // Origin dot
            Circle()
                .fill(originColor)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: originColor.opacity(isFastest ? 0.4 : 0), radius: isFastest ? 4 : 0)
                .zIndex(2)

            // Gradient line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Glow behind (fastest only)
                    if isFastest {
                        gradientLine
                            .frame(height: lineThickness + 6)
                            .opacity(0.08)
                            .blur(radius: 2)
                    }

                    // Main line
                    gradientLine
                        .frame(height: lineThickness)
                        .mask(
                            Rectangle()
                                .frame(width: geo.size.width * drawProgress)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )

                    // Incident diamond (if applicable)
                    if route.hasIncidents {
                        incidentDiamond
                            .position(x: geo.size.width * 0.45, y: geo.size.height / 2)
                            .opacity(Double(drawProgress))
                    }
                }
            }
            .frame(height: dotSize)
            .padding(.horizontal, -2)

            // Destination dot
            Circle()
                .fill(destinationColor)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: destinationColor.opacity(isFastest ? 0.3 : 0), radius: isFastest ? 4 : 0)
                .zIndex(2)
        }
        .opacity(overallOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(isFastest ? 0 : 0.15)) {
                drawProgress = 1.0
            }
        }
    }

    private var gradientLine: some View {
        let delayRatio = fastestTravelTime > 0
            ? (route.travelTime - fastestTravelTime) / fastestTravelTime
            : 0

        let gradient: LinearGradient
        if delayRatio < 0.1 {
            // Clear — solid green
            gradient = LinearGradient(
                colors: [.green],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if delayRatio < 0.3 {
            // Moderate — green/amber/green
            gradient = LinearGradient(
                stops: [
                    .init(color: Color(red: 0.29, green: 0.68, blue: 0.50), location: 0),
                    .init(color: Color(red: 0.98, green: 0.75, blue: 0.14), location: 0.4),
                    .init(color: Color(red: 0.98, green: 0.75, blue: 0.14), location: 0.6),
                    .init(color: Color(red: 0.29, green: 0.68, blue: 0.50), location: 1.0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            // Heavy — green/red/green
            gradient = LinearGradient(
                stops: [
                    .init(color: Color(red: 0.29, green: 0.68, blue: 0.50), location: 0),
                    .init(color: Color(red: 0.98, green: 0.75, blue: 0.14), location: 0.25),
                    .init(color: Color(red: 0.97, green: 0.44, blue: 0.44), location: 0.45),
                    .init(color: Color(red: 0.97, green: 0.44, blue: 0.44), location: 0.55),
                    .init(color: Color(red: 0.98, green: 0.75, blue: 0.14), location: 0.75),
                    .init(color: Color(red: 0.29, green: 0.68, blue: 0.50), location: 1.0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        return RoundedRectangle(cornerRadius: 2)
            .fill(gradient)
    }

    private var incidentDiamond: some View {
        Rectangle()
            .fill(Color(red: 0.96, green: 0.62, blue: 0.04))
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(45))
            .shadow(color: Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.5), radius: 3)
    }

    private var originColor: Color {
        isFastest
            ? Color(red: 0.29, green: 0.68, blue: 0.50)
            : (colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.15))
    }

    private var destinationColor: Color {
        isFastest
            ? Color(red: 0.97, green: 0.44, blue: 0.44)
            : (colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.15))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TrafficMenubar/Views/StylizedRouteLineView.swift
git commit -m "feat: add StylizedRouteLineView with heuristic gradient and draw-in animation"
```

---

## Task 9: Create RouteListView

**Files:**
- Create: `TrafficMenubar/Views/RouteListView.swift`

- [ ] **Step 1: Create the route list card component**

```swift
import SwiftUI

struct RouteListView: View {
    let result: RouteResult
    let onRouteTap: (Route) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.devDesignOverrides) private var designOverrides

    private var fontScale: CGFloat { designOverrides?.fontScale ?? 1.0 }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(result.routes.enumerated()), id: \.element.id) { index, route in
                let isFastest = index == 0

                routeRow(route: route, isFastest: isFastest)

                if index < result.routes.count - 1 {
                    Divider()
                        .opacity(colorScheme == .dark ? 0.06 : 0.08)
                }
            }

            // Footer
            Divider().opacity(colorScheme == .dark ? 0.06 : 0.08)
            Text("Tap route to see on map")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: Design.routeCardCornerRadius)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.02)
                    : Color.black.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.routeCardCornerRadius)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.06)
                        : Color.black.opacity(0.05),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Design.routeCardCornerRadius))
    }

    @ViewBuilder
    private func routeRow(route: Route, isFastest: Bool) -> some View {
        let fastestTime = result.fastestRoute?.travelTime ?? route.travelTime
        let delta = route.travelTimeMinutes - (result.fastestRoute?.travelTimeMinutes ?? 0)

        Button(action: { onRouteTap(route) }) {
            VStack(alignment: .leading, spacing: 0) {
                // Name + time row
                HStack {
                    // Route name + incident badge
                    HStack(spacing: 5) {
                        Text(route.name)
                            .font(Design.routeNameFont(scale: fontScale, isFastest: isFastest))
                            .foregroundColor(isFastest
                                ? (colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.7))
                                : (colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)))

                        if route.hasIncidents {
                            incidentBadge
                        }
                    }

                    Spacer()

                    // Time + delta
                    HStack(spacing: 4) {
                        Text("\(route.travelTimeMinutes) min")
                            .font(Design.routeTimeFont(scale: fontScale, isFastest: isFastest))
                            .foregroundColor(isFastest
                                ? (colorScheme == .dark ? TrafficMood.clear.darkAccentColor : TrafficMood.clear.lightTextColor)
                                : (colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.3)))

                        if !isFastest && delta > 0 {
                            Text("+\(delta)")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                        }
                    }
                }

                // Incident description (if applicable)
                if route.hasIncidents, let notice = route.advisoryNotices.first {
                    Text(notice)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.25) : .black.opacity(0.2))
                        .lineLimit(1)
                        .padding(.top, 2)
                }

                // Stylized route line
                StylizedRouteLineView(
                    route: route,
                    fastestTravelTime: fastestTime,
                    isFastest: isFastest
                )
                .frame(height: isFastest ? 20 : 16)
                .padding(.top, 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isFastest
                ? TrafficMood.clear.darkAccentColor.opacity(0.04)
                : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var incidentBadge: some View {
        HStack(spacing: 3) {
            Rectangle()
                .fill(Color(red: 0.96, green: 0.62, blue: 0.04))
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))

            Text("INCIDENT")
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TrafficMenubar/Views/RouteListView.swift
git commit -m "feat: add RouteListView with multi-route display and incident badges"
```

---

## Task 10: Create ExpandableMapView

**Files:**
- Create: `TrafficMenubar/Views/ExpandableMapView.swift`

- [ ] **Step 1: Create the tap-to-expand map wrapper**

```swift
import SwiftUI
import MapKit

struct ExpandableMapView: View {
    let routes: [Route]
    let selectedRoute: Route?
    let originCoordinate: Coordinate
    let destinationCoordinate: Coordinate
    @Binding var isExpanded: Bool

    var body: some View {
        if isExpanded, let selected = selectedRoute {
            MapPreviewView(
                routes: routes,
                primaryRouteIndex: routes.firstIndex(where: { $0.id == selected.id }) ?? 0,
                originCoordinate: originCoordinate,
                destinationCoordinate: destinationCoordinate
            )
            .frame(height: Design.mapHeight)
            .clipShape(RoundedRectangle(cornerRadius: Design.smallCornerRadius))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = false
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TrafficMenubar/Views/ExpandableMapView.swift
git commit -m "feat: add ExpandableMapView for tap-to-expand route map"
```

---

## Task 11: Update MapPreviewView for Multi-Route Overlays

**Files:**
- Modify: `TrafficMenubar/Views/MapPreviewView.swift`

- [ ] **Step 1: Update the struct to accept multiple routes**

Replace the struct properties and update methods:

```swift
struct MapPreviewView: NSViewRepresentable {
    let routes: [Route]
    let primaryRouteIndex: Int
    let originCoordinate: Coordinate
    let destinationCoordinate: Coordinate
```

- [ ] **Step 2: Update `updateNSView` to render multiple polylines**

In `updateNSView`, iterate over `routes` and add each polyline. Tag the primary route's polyline so the delegate can render it differently:

```swift
func updateNSView(_ mapView: MKMapView, context: Context) {
    mapView.removeOverlays(mapView.overlays)
    mapView.removeAnnotations(mapView.annotations)

    guard !routes.isEmpty else { return }

    // Add alternate routes first (drawn behind)
    for (index, route) in routes.enumerated() where index != primaryRouteIndex {
        let coordinates = route.polylineCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let polyline = TaggedPolyline(coordinates: coordinates, count: coordinates.count)
        polyline.isPrimary = false
        mapView.addOverlay(polyline)
    }

    // Add primary route on top
    if primaryRouteIndex < routes.count {
        let primary = routes[primaryRouteIndex]
        let coordinates = primary.polylineCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let polyline = TaggedPolyline(coordinates: coordinates, count: coordinates.count)
        polyline.isPrimary = true
        mapView.addOverlay(polyline)

        // Fit to primary route
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
            animated: false
        )
    }

    // Origin/destination markers
    let originAnnotation = RouteAnnotation(
        coordinate: CLLocationCoordinate2D(latitude: originCoordinate.latitude, longitude: originCoordinate.longitude),
        annotationType: .origin
    )
    let destAnnotation = RouteAnnotation(
        coordinate: CLLocationCoordinate2D(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude),
        annotationType: .destination
    )
    mapView.addAnnotations([originAnnotation, destAnnotation])
}
```

- [ ] **Step 3: Add `TaggedPolyline` class and update renderer**

```swift
class TaggedPolyline: MKPolyline {
    var isPrimary: Bool = true
}
```

Update the coordinator's overlay renderer:
```swift
func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let polyline = overlay as? TaggedPolyline {
        let renderer = MKPolylineRenderer(polyline: polyline)
        if polyline.isPrimary {
            renderer.strokeColor = NSColor(red: 0.29, green: 0.68, blue: 0.50, alpha: 0.9)
            renderer.lineWidth = 4
        } else {
            renderer.strokeColor = NSColor.white.withAlphaComponent(0.15)
            renderer.lineWidth = 3
            renderer.lineDashPattern = [6, 4]
        }
        renderer.lineCap = .round
        renderer.lineJoin = .round
        return renderer
    }
    return MKOverlayRenderer(overlay: overlay)
}
```

- [ ] **Step 4: Remove the old incident marker rendering from `updateNSView`**

The incident display is now inline in RouteListView. Remove the incident annotation loop.

- [ ] **Step 5: Commit**

```bash
git add TrafficMenubar/Views/MapPreviewView.swift
git commit -m "feat: update MapPreviewView for multi-route overlays with primary/alternate styling"
```

---

## Task 12: Remove IncidentBannerView

**Files:**
- Remove: `TrafficMenubar/Views/IncidentBannerView.swift`

- [ ] **Step 1: Delete the file**

```bash
rm TrafficMenubar/Views/IncidentBannerView.swift
```

Incident display is now handled inline by RouteListView's incident badge and advisory notice text.

- [ ] **Step 2: Commit**

```bash
git add -A TrafficMenubar/Views/IncidentBannerView.swift
git commit -m "refactor: remove IncidentBannerView, replaced by inline route incident display"
```

---

## Task 13: Rewrite PopoverView

**Files:**
- Modify: `TrafficMenubar/Views/PopoverView.swift`

This is the largest task. The popover gets the full adaptive theme, atmospheric glow, pulse badge, and route list.

- [ ] **Step 1: Replace the entire PopoverView with the new implementation**

```swift
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @State private var showQuickSettings = false
    @State private var moodPhrase: String = ""
    @State private var expandedRoute: Route?
    @State private var showMap = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.devDesignOverrides) private var designOverrides

    private var fontScale: CGFloat { designOverrides?.fontScale ?? 1.0 }

    private var mood: TrafficMood {
        if let override = designOverrides?.moodOverride {
            return override
        }
        return viewModel.mood
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent stripe
            LinearGradient(
                colors: [mood.darkAccentColor, mood.accentGradientEnd],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
            .animation(.easeInOut(duration: 0.4), value: mood)

            ZStack(alignment: .topTrailing) {
                // Atmospheric glow
                atmosphericGlow

                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    moodBadge

                    if let result = viewModel.currentResult {
                        if result.shouldCollapse {
                            singleRouteView(result: result)
                        } else {
                            RouteListView(result: result) { route in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if expandedRoute?.id == route.id {
                                        showMap = false
                                        expandedRoute = nil
                                    } else {
                                        expandedRoute = route
                                        showMap = true
                                    }
                                }
                            }
                        }

                        if showMap {
                            ExpandableMapView(
                                routes: result.routes,
                                selectedRoute: expandedRoute,
                                originCoordinate: originCoordinate,
                                destinationCoordinate: destinationCoordinate,
                                isExpanded: $showMap
                            )
                        }
                    }

                    footerSection
                }
                .padding(Design.popoverPadding)
            }
        }
        .background(backgroundGradient)
        .frame(width: Design.popoverWidth)
        .animation(.easeInOut(duration: 0.5), value: viewModel.fastestRoute?.travelTimeMinutes)
        .onAppear { updatePhrase() }
        .onChange(of: mood) { _ in updatePhrase() }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Design.darkBgTop, Design.darkBgBottom]
                : [Design.lightBgTop, Design.lightBgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var atmosphericGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [mood.darkAccentColor.opacity(colorScheme == .dark ? 0.10 : 0.06), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: colorScheme == .dark ? 80 : 60
                )
            )
            .frame(width: 160, height: 160)
            .offset(x: 40, y: -40)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.6), value: mood)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                directionLabel

                if viewModel.isLoading && viewModel.currentResult == nil {
                    loadingState
                } else if viewModel.hasError && viewModel.currentResult == nil {
                    errorState
                } else if let route = viewModel.fastestRoute {
                    heroTime(minutes: route.travelTimeMinutes)
                } else {
                    emptyState
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("ARRIVE BY")
                    .font(Design.labelFont(scale: fontScale))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                    .tracking(1.2)

                if let route = viewModel.fastestRoute {
                    Text(route.eta, style: .time)
                        .font(Design.etaValueFont(scale: fontScale))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .primary)
                } else {
                    Text("—:——")
                        .font(Design.etaValueFont(scale: fontScale))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.25) : .secondary.opacity(0.5))
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var directionLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: viewModel.direction == .toWork ? "building.2" : "house")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(mood.darkAccentColor)

            Text(viewModel.direction == .toWork ? "TO WORK" : "TO HOME")
                .font(Design.labelFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                .tracking(1.2)
        }
    }

    @ViewBuilder
    private func heroTime(minutes: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(minutes)")
                .font(Design.heroTimeFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white : Design.darkText)
                .contentTransition(.numericText())

            Text("min")
                .font(Design.heroUnitFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
        }
    }

    // MARK: - Mood Badge

    @ViewBuilder
    private var moodBadge: some View {
        if viewModel.currentResult != nil {
            HStack(spacing: 8) {
                PulseDotView(mood: mood, size: 10)

                Text(moodPhrase)
                    .font(Design.moodFont(scale: fontScale))
                    .foregroundColor(colorScheme == .dark ? mood.darkAccentColor : mood.lightTextColor)

                if let route = viewModel.fastestRoute, route.delayMinutes > 0 {
                    Text("· +\(route.delayMinutes) min")
                        .font(Design.moodFont(scale: fontScale))
                        .foregroundColor(colorScheme == .dark ? mood.darkAccentColor : mood.lightTextColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(mood.darkAccentColor.opacity(0.08))
            .overlay(
                Capsule()
                    .strokeBorder(mood.darkAccentColor.opacity(0.15), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }

    // MARK: - Single Route (Smart Collapse)

    @ViewBuilder
    private func singleRouteView(result: RouteResult) -> some View {
        if let route = result.fastestRoute {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expandedRoute = route
                    showMap.toggle()
                }
            }) {
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        StylizedRouteLineView(
                            route: route,
                            fastestTravelTime: route.travelTime,
                            isFastest: true
                        )
                        .frame(height: 20)

                        HStack {
                            Text(viewModel.direction == .toWork ? "Home" : "Work")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3))
                                .textCase(.uppercase)

                            Spacer()

                            Text("\(route.name) · \(String(format: "%.1f", route.distance / 1609.34)) mi")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.3))

                            Spacer()

                            Text(viewModel.direction == .toWork ? "Work" : "Home")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3))
                                .textCase(.uppercase)
                        }
                    }
                    .padding(14)

                    Divider().opacity(colorScheme == .dark ? 0.06 : 0.08)

                    Text("Tap to see on map")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: Design.routeCardCornerRadius)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Design.routeCardCornerRadius)
                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Design.routeCardCornerRadius))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        HStack(spacing: 6) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }

            if let updateText = viewModel.timeSinceUpdate {
                Text(updateText)
                    .font(Design.captionFont(scale: fontScale))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.7))
            }

            if viewModel.hasError {
                HStack(spacing: 3) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 10))
                    Text("Offline")
                        .font(Design.captionFont(scale: fontScale))
                }
                .foregroundColor(.orange.opacity(0.8))
            }

            if viewModel.isDevMode {
                HStack(spacing: 3) {
                    Image(systemName: "hammer")
                        .font(.system(size: 9))
                    Text("DEV")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()

            Button(action: { showQuickSettings.toggle() }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .popover(isPresented: $showQuickSettings) {
                QuickSettingsView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Empty / Loading / Error

    @ViewBuilder
    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: EmptyState.loading.icon)
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                Text(mood.randomPhrase())
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
            }
        }
    }

    @ViewBuilder
    private var errorState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: EmptyState.error.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                Text(EmptyState.errorPhrases.randomElement() ?? EmptyState.error.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
            Text("Will retry automatically")
                .font(Design.captionFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: EmptyState.noRoute.icon)
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                Text(EmptyState.noRoute.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
            Text(EmptyState.noRoute.subtitle)
                .font(Design.captionFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
        }
    }

    // MARK: - Helpers

    private var originCoordinate: Coordinate {
        let home = viewModel.settings.homeCoordinate ?? Coordinate(latitude: 0, longitude: 0)
        let work = viewModel.settings.workCoordinate ?? Coordinate(latitude: 0, longitude: 0)
        return viewModel.direction == .toWork ? home : work
    }

    private var destinationCoordinate: Coordinate {
        let home = viewModel.settings.homeCoordinate ?? Coordinate(latitude: 0, longitude: 0)
        let work = viewModel.settings.workCoordinate ?? Coordinate(latitude: 0, longitude: 0)
        return viewModel.direction == .toWork ? work : home
    }

    private func updatePhrase() {
        moodPhrase = mood.randomPhrase()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TrafficMenubar/Views/PopoverView.swift
git commit -m "feat: rewrite PopoverView with adaptive theme, atmospheric glow, route list, pulse badge"
```

---

## Task 14: Update DeveloperSettingsView References

**Files:**
- Modify: `TrafficMenubar/Views/DeveloperSettingsView.swift`

- [ ] **Step 1: Find and update references to old API**

Search for these patterns and update them:
- `buildRoute()` → `buildRoutes()`
- `viewModel.currentRoute` → `viewModel.currentResult`
- `updateFromMock(route:` → `updateFromMock(result:`
- `computedMood.moodEmoji` → remove (deleted property)
- `computedMood.moodPhrase` → `computedMood.randomPhrase()`
- Any reference to `moodEmoji` or `moodPhrase` (both removed in Task 6)

Specifically, line ~167 has `Text("\(computedMood.moodEmoji) \(computedMood.moodPhrase)")` — replace with `Text(computedMood.randomPhrase())`.

- [ ] **Step 2: Commit**

```bash
git add TrafficMenubar/Views/DeveloperSettingsView.swift
git commit -m "refactor: update DeveloperSettingsView for multi-route API"
```

---

## Task 15: Update TrafficMenubarApp Menubar Label

**Files:**
- Modify: `TrafficMenubar/TrafficMenubarApp.swift`

- [ ] **Step 1: No changes needed to the menubar label**

The `menuBarText` computed property on `CommuteViewModel` already handles the label format. The `menuBarSuffix` was updated in Task 6 to use `●` and `▲`. The `Text(viewModel.menuBarText)` in the app file will automatically pick up the new suffixes.

Verify the label works. If `MenuBarExtra` renders the unicode symbols, we're done. If not, investigate using `Label` with SF Symbols.

- [ ] **Step 2: Commit (only if changes were needed)**

---

## Task 16: Add/Remove Files in Xcode Project and Build

**Files:**
- Modify: `TrafficMenubar.xcodeproj/project.pbxproj`
- Various (fix any remaining compilation issues)

- [ ] **Step 1: Add new files to the Xcode project**

The project uses a traditional Xcode project with explicit file references in `project.pbxproj`. New files created on disk are NOT automatically included in the build. Open the project in Xcode and add these files to the `TrafficMenubar` target:
- `TrafficMenubar/Views/PulseDotView.swift`
- `TrafficMenubar/Views/StylizedRouteLineView.swift`
- `TrafficMenubar/Views/RouteListView.swift`
- `TrafficMenubar/Views/ExpandableMapView.swift`

Also verify `IncidentBannerView.swift` has been removed from the project (not just deleted from disk).

Alternatively, use a script or manually edit `project.pbxproj` to add `PBXBuildFile` and `PBXFileReference` entries.

- [ ] **Step 2: Build the project**

```bash
cd /Users/kevinguebert/Documents/Development/traffic-menubar
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build 2>&1 | tail -50
```

- [ ] **Step 2: Fix any compilation errors**

Common expected issues:
- `DeveloperSettingsView` references to old `buildRoute()` / `currentRoute`
- Any remaining references to `route.routePolyline` (old property name)
- Any references to `IncidentBannerView` (removed)
- Type mismatches from `RouteResult` shape changes

Fix each error, verify the build passes.

- [ ] **Step 3: Commit all fixes**

```bash
git add -A
git commit -m "fix: resolve compilation errors from multi-route migration"
```

---

## Task 17: Visual Smoke Test with Developer Mode

- [ ] **Step 1: Run the app and open the Developer Settings window**

- [ ] **Step 2: Test all mood states visually**

Using dev mode, cycle through:
- Clear (25 min travel / 25 min normal)
- Moderate (35 min travel / 25 min normal)
- Heavy (55 min travel / 25 min normal, with incidents)
- Unknown (no route)

Verify for each state:
- Accent stripe color changes
- Atmospheric glow tints to mood color
- Pulse dot animates at the correct speed
- Mood phrase rotates on refresh
- Route list shows correctly with stylized lines

- [ ] **Step 3: Test light/dark mode**

Toggle macOS appearance in System Settings → Appearance. Verify both modes look correct.

- [ ] **Step 4: Test multi-route display**

In dev mode, ensure mock data shows 2-3 routes with the fastest highlighted.

- [ ] **Step 5: Test map expand/collapse**

Tap a route row — map should expand with smooth animation. Tap again to collapse.

- [ ] **Step 6: Commit any visual fixes**

```bash
git add -A
git commit -m "fix: visual polish from smoke testing"
```
