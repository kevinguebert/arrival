# Traffic Menubar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menubar app that shows live commute time with traffic, incident alerts, and a route map preview.

**Architecture:** Pure SwiftUI app using `MenuBarExtra` (macOS 13+). A `TrafficProvider` protocol abstracts traffic data sources, with Apple MapKit as the v1 implementation. `CommuteViewModel` drives smart polling and direction detection. Location-based direction with time-based fallback.

**Tech Stack:** Swift, SwiftUI, MapKit, CoreLocation, AppKit (NSViewRepresentable for MKMapView), SMAppService (launch at login)

**Spec:** `docs/superpowers/specs/2026-03-24-traffic-menubar-design.md`

---

### Task 1: Xcode Project Setup

**Files:**
- Create: `TrafficMenubar.xcodeproj` (via Xcode CLI)
- Create: `TrafficMenubar/TrafficMenubarApp.swift`
- Create: `.gitignore`

- [ ] **Step 1: Create Xcode project via command line**

```bash
cd /Users/kevinguebert/Documents/Development/traffic-menubar
mkdir -p TrafficMenubar
```

Create the Swift Package / Xcode project. Since we're building a menubar-only app, we need a macOS App target with no main window. Create the project using `swift package init` won't work for a GUI app — we need to create the project files manually.

Create `Package.swift` — actually, for a macOS menubar app with MapKit and CoreLocation, a standard Xcode project is needed. We'll create the project structure manually and generate the `.xcodeproj` using `xcodegen` or create it by hand.

Create a `project.yml` for XcodeGen:

```yaml
name: TrafficMenubar
options:
  bundleIdPrefix: com.trafficmenubar
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"
targets:
  TrafficMenubar:
    type: application
    platform: macOS
    sources:
      - TrafficMenubar
    settings:
      base:
        INFOPLIST_KEY_LSUIElement: true
        INFOPLIST_KEY_NSLocationWhenInUseUsageDescription: "Traffic Menubar uses your location to detect whether you're near home or work to show the right commute direction."
        PRODUCT_BUNDLE_IDENTIFIER: com.trafficmenubar.app
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: 1
        SWIFT_VERSION: "5.9"
        MACOSX_DEPLOYMENT_TARGET: "13.0"
    entitlements:
      path: TrafficMenubar/TrafficMenubar.entitlements
      properties:
        com.apple.security.app-sandbox: true
        com.apple.security.network.client: true
        com.apple.security.personal-information.location: true
```

Note: `LSUIElement: true` makes this an agent app (no dock icon, no main menu — menubar only).

- [ ] **Step 2: Create the app entry point**

Create `TrafficMenubar/TrafficMenubarApp.swift`:

```swift
import SwiftUI

@main
struct TrafficMenubarApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text("Traffic Menubar — Coming Soon")
        } label: {
            Text("--m")
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 3: Create entitlements file**

Create `TrafficMenubar/TrafficMenubar.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.personal-information.location</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: Create .gitignore**

```
# Xcode
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
build/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.moved-aside
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
.swiftpm/

# macOS
.DS_Store
*.swp
*~

# Superpowers
.superpowers/

# XcodeGen
*.xcodeproj
```

- [ ] **Step 5: Install xcodegen and generate project**

```bash
brew install xcodegen
cd /Users/kevinguebert/Documents/Development/traffic-menubar
xcodegen generate
```

Expected: `TrafficMenubar.xcodeproj` is created.

- [ ] **Step 6: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED. The app should show "--m" in the menubar when run.

- [ ] **Step 7: Commit**

```bash
git add .gitignore project.yml TrafficMenubar/TrafficMenubarApp.swift TrafficMenubar/TrafficMenubar.entitlements
git commit -m "feat: scaffold Xcode project with MenuBarExtra shell"
```

---

### Task 2: Data Models

**Files:**
- Create: `TrafficMenubar/Models/RouteResult.swift`
- Create: `TrafficMenubar/Models/CommuteDirection.swift`

- [ ] **Step 1: Create RouteResult and related types**

Create `TrafficMenubar/Models/RouteResult.swift`:

```swift
import Foundation

struct Coordinate: Equatable, Codable {
    let latitude: Double
    let longitude: Double
}

enum IncidentSeverity: String, Codable {
    case minor
    case major
    case severe
}

struct TrafficIncident: Equatable, Codable {
    let description: String
    let severity: IncidentSeverity
    let location: Coordinate
}

struct RouteResult {
    let travelTime: TimeInterval
    let normalTravelTime: TimeInterval
    let eta: Date
    let incidents: [TrafficIncident]
    let routePolyline: [Coordinate]

    var delayMinutes: Int {
        let delay = travelTime - normalTravelTime
        return max(0, Int(delay / 60))
    }

    var travelTimeMinutes: Int {
        Int(travelTime / 60)
    }

    var hasIncidents: Bool {
        !incidents.isEmpty
    }
}
```

- [ ] **Step 2: Create CommuteDirection**

Create `TrafficMenubar/Models/CommuteDirection.swift`:

```swift
import Foundation

enum CommuteDirection: String, CaseIterable {
    case toWork
    case toHome

    var displayName: String {
        switch self {
        case .toWork: return "Commute to Work"
        case .toHome: return "Commute Home"
        }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Models/
git commit -m "feat: add RouteResult and CommuteDirection data models"
```

---

### Task 3: SettingsStore

**Files:**
- Create: `TrafficMenubar/Utilities/SettingsStore.swift`

- [ ] **Step 1: Create SettingsStore**

Create `TrafficMenubar/Utilities/SettingsStore.swift`:

```swift
import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var homeAddress: String {
        didSet { UserDefaults.standard.set(homeAddress, forKey: "homeAddress") }
    }
    @Published var workAddress: String {
        didSet { UserDefaults.standard.set(workAddress, forKey: "workAddress") }
    }
    @Published var homeCoordinate: Coordinate? {
        didSet {
            if let coord = homeCoordinate {
                UserDefaults.standard.set(coord.latitude, forKey: "homeLatitude")
                UserDefaults.standard.set(coord.longitude, forKey: "homeLongitude")
            } else {
                UserDefaults.standard.removeObject(forKey: "homeLatitude")
                UserDefaults.standard.removeObject(forKey: "homeLongitude")
            }
        }
    }
    @Published var workCoordinate: Coordinate? {
        didSet {
            if let coord = workCoordinate {
                UserDefaults.standard.set(coord.latitude, forKey: "workLatitude")
                UserDefaults.standard.set(coord.longitude, forKey: "workLongitude")
            } else {
                UserDefaults.standard.removeObject(forKey: "workLatitude")
                UserDefaults.standard.removeObject(forKey: "workLongitude")
            }
        }
    }

    // Commute hours — stored as hour (0-23) and minute (0-59)
    @Published var morningStartHour: Int {
        didSet { UserDefaults.standard.set(morningStartHour, forKey: "morningStartHour") }
    }
    @Published var morningStartMinute: Int {
        didSet { UserDefaults.standard.set(morningStartMinute, forKey: "morningStartMinute") }
    }
    @Published var morningEndHour: Int {
        didSet { UserDefaults.standard.set(morningEndHour, forKey: "morningEndHour") }
    }
    @Published var morningEndMinute: Int {
        didSet { UserDefaults.standard.set(morningEndMinute, forKey: "morningEndMinute") }
    }
    @Published var eveningStartHour: Int {
        didSet { UserDefaults.standard.set(eveningStartHour, forKey: "eveningStartHour") }
    }
    @Published var eveningStartMinute: Int {
        didSet { UserDefaults.standard.set(eveningStartMinute, forKey: "eveningStartMinute") }
    }
    @Published var eveningEndHour: Int {
        didSet { UserDefaults.standard.set(eveningEndHour, forKey: "eveningEndHour") }
    }
    @Published var eveningEndMinute: Int {
        didSet { UserDefaults.standard.set(eveningEndMinute, forKey: "eveningEndMinute") }
    }

    // Polling intervals in seconds
    @Published var commutePollingInterval: TimeInterval {
        didSet { UserDefaults.standard.set(commutePollingInterval, forKey: "commutePollingInterval") }
    }
    @Published var offPeakPollingInterval: TimeInterval {
        didSet { UserDefaults.standard.set(offPeakPollingInterval, forKey: "offPeakPollingInterval") }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    var isConfigured: Bool {
        homeCoordinate != nil && workCoordinate != nil
    }

    private init() {
        let defaults = UserDefaults.standard
        self.homeAddress = defaults.string(forKey: "homeAddress") ?? ""
        self.workAddress = defaults.string(forKey: "workAddress") ?? ""

        if defaults.object(forKey: "homeLatitude") != nil {
            self.homeCoordinate = Coordinate(
                latitude: defaults.double(forKey: "homeLatitude"),
                longitude: defaults.double(forKey: "homeLongitude")
            )
        } else {
            self.homeCoordinate = nil
        }

        if defaults.object(forKey: "workLatitude") != nil {
            self.workCoordinate = Coordinate(
                latitude: defaults.double(forKey: "workLatitude"),
                longitude: defaults.double(forKey: "workLongitude")
            )
        } else {
            self.workCoordinate = nil
        }

        // Defaults: Morning 7:00-9:30, Evening 16:00-19:00
        self.morningStartHour = defaults.object(forKey: "morningStartHour") as? Int ?? 7
        self.morningStartMinute = defaults.object(forKey: "morningStartMinute") as? Int ?? 0
        self.morningEndHour = defaults.object(forKey: "morningEndHour") as? Int ?? 9
        self.morningEndMinute = defaults.object(forKey: "morningEndMinute") as? Int ?? 30
        self.eveningStartHour = defaults.object(forKey: "eveningStartHour") as? Int ?? 16
        self.eveningStartMinute = defaults.object(forKey: "eveningStartMinute") as? Int ?? 0
        self.eveningEndHour = defaults.object(forKey: "eveningEndHour") as? Int ?? 19
        self.eveningEndMinute = defaults.object(forKey: "eveningEndMinute") as? Int ?? 0

        // Defaults: 3 min commute, 15 min off-peak
        self.commutePollingInterval = defaults.object(forKey: "commutePollingInterval") as? TimeInterval ?? 180
        self.offPeakPollingInterval = defaults.object(forKey: "offPeakPollingInterval") as? TimeInterval ?? 900

        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }

    func isCommuteHour(at date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let timeValue = hour * 60 + minute

        let morningStart = morningStartHour * 60 + morningStartMinute
        let morningEnd = morningEndHour * 60 + morningEndMinute
        let eveningStart = eveningStartHour * 60 + eveningStartMinute
        let eveningEnd = eveningEndHour * 60 + eveningEndMinute

        return (timeValue >= morningStart && timeValue <= morningEnd)
            || (timeValue >= eveningStart && timeValue <= eveningEnd)
    }

    var currentPollingInterval: TimeInterval {
        let interval = isCommuteHour() ? commutePollingInterval : offPeakPollingInterval
        return max(60, interval) // Rate limit floor: 1 request per minute
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Utilities/SettingsStore.swift
git commit -m "feat: add SettingsStore with UserDefaults persistence and smart polling intervals"
```

---

### Task 4: TrafficProvider Protocol + MapKit Implementation

**Files:**
- Create: `TrafficMenubar/Providers/TrafficProvider.swift`
- Create: `TrafficMenubar/Providers/MapKitProvider.swift`

- [ ] **Step 1: Create TrafficProvider protocol**

Create `TrafficMenubar/Providers/TrafficProvider.swift`:

```swift
import Foundation

enum TrafficProviderError: Error, LocalizedError {
    case noRouteFound
    case geocodingFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "No route found between the two locations."
        case .geocodingFailed(let address):
            return "Could not find location for: \(address)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

protocol TrafficProvider {
    func fetchRoute(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult
}
```

- [ ] **Step 2: Create MapKitProvider**

Create `TrafficMenubar/Providers/MapKitProvider.swift`:

```swift
import Foundation
import MapKit

final class MapKitProvider: TrafficProvider {
    func fetchRoute(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
        ))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        ))
        request.transportType = .automobile
        request.departureDate = Date()

        let directions = MKDirections(request: request)

        let response: MKDirections.Response
        do {
            response = try await directions.calculate()
        } catch {
            throw TrafficProviderError.networkError(error)
        }

        guard let route = response.routes.first else {
            throw TrafficProviderError.noRouteFound
        }

        let travelTime = route.expectedTravelTime
        // MapKit doesn't separate traffic vs non-traffic time directly.
        // Use the static distance-based estimate as the "normal" baseline.
        // expectedTravelTime already includes traffic conditions.
        let normalTravelTime = estimateNormalTravelTime(distanceMeters: route.distance)

        let polyline = extractPolyline(from: route.polyline)

        return RouteResult(
            travelTime: travelTime,
            normalTravelTime: normalTravelTime,
            eta: Date().addingTimeInterval(travelTime),
            incidents: [], // MapKit MKDirections does not expose incident data
            routePolyline: polyline
        )
    }

    private func estimateNormalTravelTime(distanceMeters: Double) -> TimeInterval {
        // Rough baseline: assume average 50 km/h (~31 mph) for urban/suburban driving
        let averageSpeedMPS = 50.0 * 1000.0 / 3600.0 // ~13.9 m/s
        return distanceMeters / averageSpeedMPS
    }

    private func extractPolyline(from polyline: MKPolyline) -> [Coordinate] {
        let pointCount = polyline.pointCount
        let points = polyline.points()
        var coordinates: [Coordinate] = []
        coordinates.reserveCapacity(pointCount)

        // Sample at most 100 points to keep the data lightweight
        let stride = max(1, pointCount / 100)
        for i in Swift.stride(from: 0, to: pointCount, by: stride) {
            let mapPoint = points[i]
            let coord = mapPoint.coordinate
            coordinates.append(Coordinate(latitude: coord.latitude, longitude: coord.longitude))
        }

        // Always include the last point
        if let lastIndex = (0..<pointCount).last, coordinates.last != Coordinate(latitude: points[lastIndex].coordinate.latitude, longitude: points[lastIndex].coordinate.longitude) {
            let coord = points[lastIndex].coordinate
            coordinates.append(Coordinate(latitude: coord.latitude, longitude: coord.longitude))
        }

        return coordinates
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Providers/
git commit -m "feat: add TrafficProvider protocol and MapKit implementation"
```

---

### Task 5: GeocodingService

**Files:**
- Create: `TrafficMenubar/Services/GeocodingService.swift`

- [ ] **Step 1: Create GeocodingService**

Create `TrafficMenubar/Services/GeocodingService.swift`:

```swift
import Foundation
import CoreLocation

final class GeocodingService {
    private let geocoder = CLGeocoder()

    func geocode(address: String) async throws -> Coordinate {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TrafficProviderError.geocodingFailed(address)
        }

        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.geocodeAddressString(address)
        } catch {
            throw TrafficProviderError.geocodingFailed(address)
        }

        guard let location = placemarks.first?.location else {
            throw TrafficProviderError.geocodingFailed(address)
        }

        return Coordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Services/GeocodingService.swift
git commit -m "feat: add GeocodingService for address-to-coordinate resolution"
```

---

### Task 6: LocationManager

**Files:**
- Create: `TrafficMenubar/Services/LocationManager.swift`

- [ ] **Step 1: Create LocationManager**

Create `TrafficMenubar/Services/LocationManager.swift`:

```swift
import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private let proximityThreshold: CLLocationDistance = 500 // meters

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        manager.requestLocation()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func detectDirection(home: Coordinate, work: Coordinate) -> CommuteDirection? {
        guard let location = currentLocation else { return nil }

        let homeCL = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let workCL = CLLocation(latitude: work.latitude, longitude: work.longitude)

        let distanceToHome = location.distance(from: homeCL)
        let distanceToWork = location.distance(from: workCL)

        if distanceToHome <= proximityThreshold {
            return .toWork
        } else if distanceToWork <= proximityThreshold {
            return .toHome
        }

        return nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently ignore — fallback to time-based detection
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Services/LocationManager.swift
git commit -m "feat: add LocationManager with proximity-based direction detection"
```

---

### Task 7: PollScheduler

**Files:**
- Create: `TrafficMenubar/Utilities/PollScheduler.swift`

- [ ] **Step 1: Create PollScheduler**

Create `TrafficMenubar/Utilities/PollScheduler.swift`:

```swift
import Foundation
import AppKit
import Combine

final class PollScheduler: ObservableObject {
    private var pollTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let settings: SettingsStore
    private let onPoll: () async -> Void

    @Published var isPaused = false

    init(settings: SettingsStore, onPoll: @escaping () async -> Void) {
        self.settings = settings
        self.onPoll = onPoll
        observeSystemState()
    }

    func start() {
        stop()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, !self.isPaused else {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }
                await self.onPoll()
                let interval = self.settings.currentPollingInterval
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func pollNow() {
        Task {
            await onPoll()
        }
    }

    private func observeSystemState() {
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                self?.isPaused = true
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.isPaused = false
                self?.pollNow()
            }
            .store(in: &cancellables)
    }

    deinit {
        stop()
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Utilities/PollScheduler.swift
git commit -m "feat: add PollScheduler with smart intervals and sleep/wake handling"
```

---

### Task 8: CommuteViewModel

**Files:**
- Create: `TrafficMenubar/ViewModels/CommuteViewModel.swift`

- [ ] **Step 1: Create CommuteViewModel**

Create `TrafficMenubar/ViewModels/CommuteViewModel.swift`:

```swift
import Foundation
import Combine

@MainActor
final class CommuteViewModel: ObservableObject {
    @Published var currentRoute: RouteResult?
    @Published var direction: CommuteDirection = .toWork
    @Published var isLoading = false
    @Published var consecutiveFailures = 0
    @Published var lastUpdated: Date?
    @Published var directionOverride: CommuteDirection?

    let settings: SettingsStore
    let locationManager: LocationManager
    private let provider: TrafficProvider
    private var scheduler: PollScheduler?

    init(settings: SettingsStore = .shared,
         locationManager: LocationManager = LocationManager(),
         provider: TrafficProvider = MapKitProvider()) {
        self.settings = settings
        self.locationManager = locationManager
        self.provider = provider
    }

    func startPolling() {
        locationManager.requestAuthorization()

        scheduler = PollScheduler(settings: settings) { [weak self] in
            await self?.fetchRoute()
        }
        scheduler?.start()

        // Initial fetch
        Task { await fetchRoute() }
    }

    func stopPolling() {
        scheduler?.stop()
    }

    func refreshNow() {
        scheduler?.pollNow()
    }

    func setDirectionOverride(_ override: CommuteDirection?) {
        directionOverride = override
        Task { await fetchRoute() }
    }

    var menuBarText: String {
        guard let route = currentRoute else {
            return "--m"
        }
        let minutes = route.travelTimeMinutes
        let warning = route.hasIncidents ? " ⚠" : ""
        return "\(minutes)m\(warning)"
    }

    var hasError: Bool {
        consecutiveFailures >= 3
    }

    var timeSinceUpdate: String? {
        guard let lastUpdated else { return nil }
        let seconds = Date().timeIntervalSince(lastUpdated)
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "Updated just now" }
        return "Updated \(minutes)m ago"
    }

    private func fetchRoute() async {
        guard settings.isConfigured,
              let home = settings.homeCoordinate,
              let work = settings.workCoordinate else {
            return
        }

        // Determine direction
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

        isLoading = currentRoute == nil // Only show loading on first fetch
        do {
            let result = try await provider.fetchRoute(from: origin, to: destination)
            currentRoute = result
            consecutiveFailures = 0
            lastUpdated = Date()
        } catch {
            consecutiveFailures += 1
            // Keep showing last result — staleness is shown via timeSinceUpdate
        }
        isLoading = false
    }

    private func resolveDirection(home: Coordinate, work: Coordinate) -> CommuteDirection {
        // Manual override takes priority
        if let override = directionOverride {
            return override
        }

        // Location-based detection
        if let detected = locationManager.detectDirection(home: home, work: work) {
            return detected
        }

        // Time-based fallback
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? .toWork : .toHome
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/ViewModels/CommuteViewModel.swift
git commit -m "feat: add CommuteViewModel with direction detection and route fetching"
```

---

### Task 9: PopoverView + IncidentBannerView

**Files:**
- Create: `TrafficMenubar/Views/PopoverView.swift`
- Create: `TrafficMenubar/Views/IncidentBannerView.swift`

- [ ] **Step 1: Create IncidentBannerView**

Create `TrafficMenubar/Views/IncidentBannerView.swift`:

```swift
import SwiftUI

struct IncidentBannerView: View {
    let incidents: [TrafficIncident]
    let delayMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(incidents.prefix(3).enumerated()), id: \.offset) { _, incident in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(incident.description)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            if delayMinutes > 0 {
                Text("+\(delayMinutes) min vs usual")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(width: 3)
                .foregroundColor(.red),
            alignment: .leading
        )
        .cornerRadius(6)
    }
}
```

- [ ] **Step 2: Create PopoverView**

Create `TrafficMenubar/Views/PopoverView.swift`:

```swift
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @State private var showQuickSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: direction + time + ETA
            headerSection

            // Incident banner (only if incidents exist)
            if let route = viewModel.currentRoute, route.hasIncidents {
                IncidentBannerView(
                    incidents: route.incidents,
                    delayMinutes: route.delayMinutes
                )
            }

            // Delay comparison (when no incidents but there's a delay)
            if let route = viewModel.currentRoute, !route.hasIncidents, route.delayMinutes > 0 {
                Text("+\(route.delayMinutes) min vs usual")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Map preview
            if let route = viewModel.currentRoute, !route.routePolyline.isEmpty {
                MapPreviewPlaceholder(route: route)
                    .frame(height: 120)
                    .cornerRadius(8)
            }

            // Footer: last updated + settings gear
            footerSection
        }
        .padding(16)
        .frame(width: 280)
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.direction.displayName.uppercased())
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                if viewModel.isLoading {
                    Text("--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                } else if let route = viewModel.currentRoute {
                    Text("\(route.travelTimeMinutes)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    + Text(" min")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.secondary)
                } else {
                    Text("--m")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("ETA")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let route = viewModel.currentRoute {
                    Text(route.eta, style: .time)
                        .font(.system(size: 20, weight: .semibold))
                } else {
                    Text("--:--")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        HStack {
            if let updateText = viewModel.timeSinceUpdate {
                Text(updateText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if viewModel.hasError {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .help("Unable to fetch traffic data")
            }

            Spacer()

            Button(action: { showQuickSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showQuickSettings) {
                QuickSettingsPlaceholder(viewModel: viewModel)
            }
        }
    }
}

// Temporary placeholders — replaced in later tasks
struct MapPreviewPlaceholder: View {
    let route: RouteResult
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.15))
            .overlay(Text("Map Preview").font(.caption).foregroundColor(.secondary))
    }
}

struct QuickSettingsPlaceholder: View {
    @ObservedObject var viewModel: CommuteViewModel
    var body: some View {
        Text("Quick Settings").padding()
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/PopoverView.swift TrafficMenubar/Views/IncidentBannerView.swift
git commit -m "feat: add PopoverView with compact stack layout and IncidentBannerView"
```

---

### Task 10: MapPreviewView

**Files:**
- Create: `TrafficMenubar/Views/MapPreviewView.swift`
- Modify: `TrafficMenubar/Views/PopoverView.swift` (replace placeholder)

- [ ] **Step 1: Create MapPreviewView**

Create `TrafficMenubar/Views/MapPreviewView.swift`:

```swift
import SwiftUI
import MapKit

struct MapPreviewView: NSViewRepresentable {
    let routePolyline: [Coordinate]
    let originCoordinate: Coordinate
    let destinationCoordinate: Coordinate
    let incidents: [TrafficIncident]

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsZoomControls = false
        mapView.showsCompass = false
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard !routePolyline.isEmpty else { return }

        // Add route polyline
        let coordinates = routePolyline.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        // Add origin (green) and destination (red) pins
        let originAnnotation = RouteAnnotation(
            coordinate: CLLocationCoordinate2D(latitude: originCoordinate.latitude, longitude: originCoordinate.longitude),
            annotationType: .origin
        )
        let destAnnotation = RouteAnnotation(
            coordinate: CLLocationCoordinate2D(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude),
            annotationType: .destination
        )
        mapView.addAnnotations([originAnnotation, destAnnotation])

        // Add incident markers
        for incident in incidents {
            let annotation = RouteAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: incident.location.latitude, longitude: incident.location.longitude),
                annotationType: .incident
            )
            mapView.addAnnotation(annotation)
        }

        // Fit to show entire route with padding
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
            animated: false
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnotation = annotation as? RouteAnnotation else { return nil }

            let identifier = "RoutePin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation

            let size: CGFloat = 12
            let circle = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                let color: NSColor
                switch routeAnnotation.annotationType {
                case .origin: color = .systemGreen
                case .destination: color = .systemRed
                case .incident: color = .systemOrange
                }
                color.setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
                return true
            }
            view.image = circle
            view.frame.size = NSSize(width: size, height: size)

            return view
        }
    }
}

enum RouteAnnotationType {
    case origin
    case destination
    case incident
}

class RouteAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let annotationType: RouteAnnotationType

    init(coordinate: CLLocationCoordinate2D, annotationType: RouteAnnotationType) {
        self.coordinate = coordinate
        self.annotationType = annotationType
    }
}
```

- [ ] **Step 2: Replace placeholder in PopoverView**

In `TrafficMenubar/Views/PopoverView.swift`, replace the `MapPreviewPlaceholder` usage and struct:

Replace this in the body:
```swift
MapPreviewPlaceholder(route: route)
```

With:
```swift
if let home = viewModel.settings.homeCoordinate,
   let work = viewModel.settings.workCoordinate {
    MapPreviewView(
        routePolyline: route.routePolyline,
        originCoordinate: viewModel.direction == .toWork ? home : work,
        destinationCoordinate: viewModel.direction == .toWork ? work : home,
        incidents: route.incidents
    )
}
```

Remove the `MapPreviewPlaceholder` struct from PopoverView.swift.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/MapPreviewView.swift TrafficMenubar/Views/PopoverView.swift
git commit -m "feat: add MapPreviewView with route overlay and endpoint markers"
```

---

### Task 11: QuickSettingsView

**Files:**
- Create: `TrafficMenubar/Views/QuickSettingsView.swift`
- Modify: `TrafficMenubar/Views/PopoverView.swift` (replace placeholder)

- [ ] **Step 1: Create QuickSettingsView**

Create `TrafficMenubar/Views/QuickSettingsView.swift`:

```swift
import SwiftUI

struct QuickSettingsView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Settings")
                .font(.headline)

            Divider()

            // Direction toggle
            Button(action: {
                let newDirection: CommuteDirection = viewModel.direction == .toWork ? .toHome : .toWork
                viewModel.setDirectionOverride(newDirection)
                dismiss()
            }) {
                Label(
                    viewModel.direction == .toWork ? "Switch to Home" : "Switch to Work",
                    systemImage: "arrow.triangle.swap"
                )
            }
            .buttonStyle(.plain)

            // Clear override (if one is set)
            if viewModel.directionOverride != nil {
                Button(action: {
                    viewModel.setDirectionOverride(nil)
                    dismiss()
                }) {
                    Label("Auto-detect direction", systemImage: "location")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Divider()

            // Refresh now
            Button(action: {
                viewModel.refreshNow()
                dismiss()
            }) {
                Label("Refresh Now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)

            Divider()

            // Open full preferences
            Button(action: {
                NotificationCenter.default.post(name: .openPreferences, object: nil)
                dismiss()
            }) {
                Label("Preferences...", systemImage: "gearshape.2")
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit Traffic Menubar", systemImage: "xmark.circle")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 200)
    }
}

extension Notification.Name {
    static let openPreferences = Notification.Name("openPreferences")
}
```

- [ ] **Step 2: Replace placeholder in PopoverView**

In `TrafficMenubar/Views/PopoverView.swift`, replace the `QuickSettingsPlaceholder` usage:

Replace:
```swift
QuickSettingsPlaceholder(viewModel: viewModel)
```

With:
```swift
QuickSettingsView(viewModel: viewModel)
```

Remove the `QuickSettingsPlaceholder` struct from PopoverView.swift.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/QuickSettingsView.swift TrafficMenubar/Views/PopoverView.swift
git commit -m "feat: add QuickSettingsView with direction toggle, refresh, and quit"
```

---

### Task 12: PreferencesView

**Files:**
- Create: `TrafficMenubar/Views/PreferencesView.swift`

- [ ] **Step 1: Create PreferencesView**

Create `TrafficMenubar/Views/PreferencesView.swift`:

```swift
import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @ObservedObject var settings: SettingsStore
    @State private var homeGeocodingError: String?
    @State private var workGeocodingError: String?
    @State private var isGeocodingHome = false
    @State private var isGeocodingWork = false

    private let geocoder = GeocodingService()

    var body: some View {
        TabView {
            addressesTab
                .tabItem { Label("Addresses", systemImage: "mappin.and.ellipse") }

            scheduleTab
                .tabItem { Label("Schedule", systemImage: "clock") }

            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 420, height: 320)
        .padding()
    }

    @ViewBuilder
    private var addressesTab: some View {
        Form {
            Section("Home Address") {
                TextField("Enter home address", text: $settings.homeAddress)
                    .onSubmit { geocodeHome() }

                HStack {
                    if isGeocodingHome {
                        ProgressView().controlSize(.small)
                        Text("Looking up address...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let error = homeGeocodingError {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error).font(.caption).foregroundColor(.orange)
                    } else if settings.homeCoordinate != nil {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("Address found").font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            Section("Work Address") {
                TextField("Enter work address", text: $settings.workAddress)
                    .onSubmit { geocodeWork() }

                HStack {
                    if isGeocodingWork {
                        ProgressView().controlSize(.small)
                        Text("Looking up address...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let error = workGeocodingError {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error).font(.caption).foregroundColor(.orange)
                    } else if settings.workCoordinate != nil {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("Address found").font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            Text("Press Return after entering an address to look it up.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func timeSlots() -> [(label: String, hour: Int, minute: Int)] {
        (0..<24).flatMap { hour in
            [0, 30].map { minute in
                (label: String(format: "%d:%02d", hour, minute), hour: hour, minute: minute)
            }
        }
    }

    private func timeTag(hour: Int, minute: Int) -> Int {
        hour * 60 + minute
    }

    @ViewBuilder
    private var scheduleTab: some View {
        Form {
            Section("Morning Commute") {
                HStack {
                    Text("From")
                    Picker("", selection: Binding(
                        get: { timeTag(hour: settings.morningStartHour, minute: settings.morningStartMinute) },
                        set: { settings.morningStartHour = $0 / 60; settings.morningStartMinute = $0 % 60 }
                    )) {
                        ForEach(timeSlots(), id: \.hour) { slot in
                            Text(slot.label).tag(timeTag(hour: slot.hour, minute: slot.minute))
                        }
                    }.frame(width: 80)
                    Text("to")
                    Picker("", selection: Binding(
                        get: { timeTag(hour: settings.morningEndHour, minute: settings.morningEndMinute) },
                        set: { settings.morningEndHour = $0 / 60; settings.morningEndMinute = $0 % 60 }
                    )) {
                        ForEach(timeSlots(), id: \.hour) { slot in
                            Text(slot.label).tag(timeTag(hour: slot.hour, minute: slot.minute))
                        }
                    }.frame(width: 80)
                }
            }

            Section("Evening Commute") {
                HStack {
                    Text("From")
                    Picker("", selection: Binding(
                        get: { timeTag(hour: settings.eveningStartHour, minute: settings.eveningStartMinute) },
                        set: { settings.eveningStartHour = $0 / 60; settings.eveningStartMinute = $0 % 60 }
                    )) {
                        ForEach(timeSlots(), id: \.hour) { slot in
                            Text(slot.label).tag(timeTag(hour: slot.hour, minute: slot.minute))
                        }
                    }.frame(width: 80)
                    Text("to")
                    Picker("", selection: Binding(
                        get: { timeTag(hour: settings.eveningEndHour, minute: settings.eveningEndMinute) },
                        set: { settings.eveningEndHour = $0 / 60; settings.eveningEndMinute = $0 % 60 }
                    )) {
                        ForEach(timeSlots(), id: \.hour) { slot in
                            Text(slot.label).tag(timeTag(hour: slot.hour, minute: slot.minute))
                        }
                    }.frame(width: 80)
                }
            }

            Section("Polling Frequency") {
                Picker("During commute hours", selection: $settings.commutePollingInterval) {
                    Text("Every 1 minute").tag(TimeInterval(60))
                    Text("Every 3 minutes").tag(TimeInterval(180))
                    Text("Every 5 minutes").tag(TimeInterval(300))
                    Text("Every 10 minutes").tag(TimeInterval(600))
                }
                Picker("Outside commute hours", selection: $settings.offPeakPollingInterval) {
                    Text("Every 5 minutes").tag(TimeInterval(300))
                    Text("Every 10 minutes").tag(TimeInterval(600))
                    Text("Every 15 minutes").tag(TimeInterval(900))
                    Text("Every 30 minutes").tag(TimeInterval(1800))
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        updateLaunchAtLogin(newValue)
                    }
                ))
            }

            Section("Location") {
                Text("Location access enables automatic direction detection (home vs. work). Without it, direction is based on time of day.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Traffic Provider") {
                Picker("Provider", selection: .constant("mapkit")) {
                    Text("Apple Maps").tag("mapkit")
                }
                .disabled(true)
                Text("More providers coming soon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func geocodeHome() {
        isGeocodingHome = true
        homeGeocodingError = nil
        Task {
            do {
                let coord = try await geocoder.geocode(address: settings.homeAddress)
                settings.homeCoordinate = coord
                homeGeocodingError = nil
            } catch {
                homeGeocodingError = "Couldn't find this address"
                settings.homeCoordinate = nil
            }
            isGeocodingHome = false
        }
    }

    private func geocodeWork() {
        isGeocodingWork = true
        workGeocodingError = nil
        Task {
            do {
                let coord = try await geocoder.geocode(address: settings.workAddress)
                settings.workCoordinate = coord
                workGeocodingError = nil
            } catch {
                workGeocodingError = "Couldn't find this address"
                settings.workCoordinate = nil
            }
            isGeocodingWork = false
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — not critical
            settings.launchAtLogin = !enabled // revert
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Views/PreferencesView.swift
git commit -m "feat: add PreferencesView with address geocoding, schedule, and general settings"
```

---

### Task 13: Wire Everything Together in TrafficMenubarApp

**Files:**
- Modify: `TrafficMenubar/TrafficMenubarApp.swift`

- [ ] **Step 1: Update app entry point**

Replace `TrafficMenubar/TrafficMenubarApp.swift` with:

```swift
import SwiftUI

@main
struct TrafficMenubarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: appDelegate.viewModel)
        } label: {
            Text(appDelegate.viewModel.menuBarText)
        }
        .menuBarExtraStyle(.window)

        Window("Preferences", id: "preferences") {
            PreferencesView(settings: appDelegate.viewModel.settings)
        }
        .defaultSize(width: 420, height: 320)
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = CommuteViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Open preferences on first launch if not configured
        if !viewModel.settings.isConfigured {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.activate(ignoringOtherApps: true)
                // Open preferences window by finding it or posting to the app
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "preferences" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }

        viewModel.startPolling()

        // Listen for open preferences notifications
        NotificationCenter.default.addObserver(
            forName: .openPreferences,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopPolling()
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run the app manually to verify**

```bash
open build/Build/Products/Debug/TrafficMenubar.app
```

Expected: "--m" appears in the menubar. Clicking shows the popover. If no addresses configured, preferences window opens.

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/TrafficMenubarApp.swift
git commit -m "feat: wire up app entry point with MenuBarExtra, popover, and preferences"
```

---

### Task 14: Regenerate Xcode Project & Final Integration Test

**Files:**
- Modify: `project.yml` (ensure all new files are picked up)

- [ ] **Step 1: Regenerate Xcode project**

```bash
cd /Users/kevinguebert/Documents/Development/traffic-menubar
xcodegen generate
```

Expected: Project regenerated with all source files included.

- [ ] **Step 2: Clean build**

```bash
xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Debug clean build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run and manually test**

```bash
open build/Build/Products/Debug/TrafficMenubar.app
```

Manual test checklist:
- [ ] App shows "--m" in menubar
- [ ] Preferences window opens on first launch
- [ ] Can enter home and work addresses, geocoding works (press Return)
- [ ] After addresses are set, commute time appears in menubar
- [ ] Clicking menubar shows popover with time, ETA, map preview
- [ ] Gear icon opens quick settings
- [ ] Quick settings: direction toggle, refresh, quit all work
- [ ] Preferences tabs: Addresses, Schedule, General all render correctly

- [ ] **Step 4: Commit**

```bash
git add project.yml
git commit -m "chore: regenerate Xcode project with all source files"
```
