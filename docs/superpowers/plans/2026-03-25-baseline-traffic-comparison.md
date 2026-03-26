# Baseline Traffic Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dual mood code paths with a unified engine that compares current travel time against a no-traffic baseline, so "green" actually means traffic is good.

**Architecture:** Add a `BaselineFetcher` service that fetches no-traffic travel times via Mapbox `driving` profile or MapKit estimate. Store per-direction baselines in `SettingsStore`. Replace the two `TrafficMood` initializers with a single unified initializer that uses percentage-over-baseline thresholds with a minute floor and congestion bump.

**Tech Stack:** Swift, SwiftUI, Mapbox Directions API v5, MapKit, UserDefaults

**Spec:** `docs/superpowers/specs/2026-03-25-baseline-traffic-comparison-design.md`

---

### Task 1: Add BaselineCompareMode enum and new fields to SettingsStore

**Files:**
- Modify: `TrafficMenubar/Utilities/SettingsStore.swift`

- [ ] **Step 1: Add the `BaselineCompareMode` enum**

Add above the `SettingsStore` class, after the `MapsApp` enum (after line 14):

```swift
enum BaselineCompareMode: String, CaseIterable {
    case bestCase = "bestCase"
    case typical = "typical"

    var displayName: String {
        switch self {
        case .bestCase: return "Best case (no traffic)"
        case .typical: return "Typical traffic"
        }
    }
}
```

- [ ] **Step 2: Add new published properties to SettingsStore**

Add after the `preferredMapsApp` property (after line 94):

```swift
@Published var baselineCompareMode: BaselineCompareMode {
    didSet { UserDefaults.standard.set(baselineCompareMode.rawValue, forKey: "baselineCompareMode") }
}
@Published var useMapboxBaseline: Bool {
    didSet { UserDefaults.standard.set(useMapboxBaseline, forKey: "useMapboxBaseline") }
}
@Published var baselineToWorkTime: TimeInterval? {
    didSet {
        if let time = baselineToWorkTime {
            UserDefaults.standard.set(time, forKey: "baselineToWorkTime")
        } else {
            UserDefaults.standard.removeObject(forKey: "baselineToWorkTime")
        }
    }
}
@Published var baselineToHomeTime: TimeInterval? {
    didSet {
        if let time = baselineToHomeTime {
            UserDefaults.standard.set(time, forKey: "baselineToHomeTime")
        } else {
            UserDefaults.standard.removeObject(forKey: "baselineToHomeTime")
        }
    }
}
@Published var baselineFetchedAt: Date? {
    didSet {
        if let date = baselineFetchedAt {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "baselineFetchedAt")
        } else {
            UserDefaults.standard.removeObject(forKey: "baselineFetchedAt")
        }
    }
}
```

- [ ] **Step 3: Initialize new properties in `init()`**

Add at the end of the `init()` method, before the closing brace (after line 153):

```swift
self.baselineCompareMode = BaselineCompareMode(rawValue: defaults.string(forKey: "baselineCompareMode") ?? "") ?? .bestCase
self.useMapboxBaseline = defaults.object(forKey: "useMapboxBaseline") as? Bool ?? true
if defaults.object(forKey: "baselineToWorkTime") != nil {
    self.baselineToWorkTime = defaults.double(forKey: "baselineToWorkTime")
} else {
    self.baselineToWorkTime = nil
}
if defaults.object(forKey: "baselineToHomeTime") != nil {
    self.baselineToHomeTime = defaults.double(forKey: "baselineToHomeTime")
} else {
    self.baselineToHomeTime = nil
}
if defaults.object(forKey: "baselineFetchedAt") != nil {
    self.baselineFetchedAt = Date(timeIntervalSince1970: defaults.double(forKey: "baselineFetchedAt"))
} else {
    self.baselineFetchedAt = nil
}
```

- [ ] **Step 4: Add a helper to clear baselines when addresses change**

Add after the `clearMapboxKey()` method:

```swift
func clearBaselines() {
    baselineToWorkTime = nil
    baselineToHomeTime = nil
    baselineFetchedAt = nil
}
```

- [ ] **Step 5: Build and verify no errors**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add TrafficMenubar/Utilities/SettingsStore.swift
git commit -m "feat: add baseline comparison fields to SettingsStore"
```

---

### Task 2: Create BaselineFetcher service and add to Xcode project

**Files:**
- Create: `TrafficMenubar/Utilities/BaselineFetcher.swift`
- Modify: `TrafficMenubar.xcodeproj/project.pbxproj` (if needed)

- [ ] **Step 1: Create the BaselineFetcher file**

Create `TrafficMenubar/Utilities/BaselineFetcher.swift`:

```swift
import Foundation
import MapKit

struct BaselineResult {
    let toWorkTime: TimeInterval
    let toHomeTime: TimeInterval
}

final class BaselineFetcher {

    enum FetchError: Error {
        case networkError(Error)
        case noRouteFound
        case invalidResponse
    }

    // MARK: - Public API

    /// Fetch no-traffic baseline times for both directions.
    /// Uses Mapbox `driving` (non-traffic) profile if key provided, otherwise MapKit.
    static func fetch(
        home: Coordinate,
        work: Coordinate,
        mapboxAPIKey: String?
    ) async throws -> BaselineResult {
        if let key = mapboxAPIKey {
            return try await fetchMapbox(home: home, work: work, apiKey: key)
        }
        return try await fetchMapKit(home: home, work: work)
    }

    // MARK: - Mapbox (non-traffic profile)

    private static func fetchMapbox(
        home: Coordinate,
        work: Coordinate,
        apiKey: String
    ) async throws -> BaselineResult {
        let toWorkTime = try await fetchMapboxDirection(
            from: home, to: work, apiKey: apiKey
        )
        let toHomeTime = try await fetchMapboxDirection(
            from: work, to: home, apiKey: apiKey
        )
        return BaselineResult(toWorkTime: toWorkTime, toHomeTime: toHomeTime)
    }

    private static func fetchMapboxDirection(
        from origin: Coordinate,
        to destination: Coordinate,
        apiKey: String
    ) async throws -> TimeInterval {
        let path = "/directions/v5/mapbox/driving/"
            + "\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)"

        guard var components = URLComponents(string: "https://api.mapbox.com" + path) else {
            throw FetchError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "access_token", value: apiKey),
            URLQueryItem(name: "overview", value: "false"),
        ]

        guard let url = components.url else {
            throw FetchError.invalidResponse
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw FetchError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw FetchError.networkError(
                URLError(URLError.Code(rawValue: httpResponse.statusCode))
            )
        }

        // Minimal decode — we only need duration from the first route
        struct Response: Codable {
            let code: String
            let routes: [RouteEntry]
            struct RouteEntry: Codable {
                let duration: Double
            }
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard decoded.code == "Ok", let firstRoute = decoded.routes.first else {
            throw FetchError.noRouteFound
        }

        return firstRoute.duration
    }

    // MARK: - MapKit fallback

    private static func fetchMapKit(
        home: Coordinate,
        work: Coordinate
    ) async throws -> BaselineResult {
        let toWorkTime = try await fetchMapKitDirection(from: home, to: work)
        let toHomeTime = try await fetchMapKitDirection(from: work, to: home)
        return BaselineResult(toWorkTime: toWorkTime, toHomeTime: toHomeTime)
    }

    private static func fetchMapKitDirection(
        from origin: Coordinate,
        to destination: Coordinate
    ) async throws -> TimeInterval {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
        ))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        ))
        request.transportType = .automobile
        // No departureDate — request baseline estimate without real-time traffic

        let directions = MKDirections(request: request)

        let response: MKDirections.Response
        do {
            response = try await directions.calculate()
        } catch {
            throw FetchError.networkError(error)
        }

        guard let fastest = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
            throw FetchError.noRouteFound
        }

        // MapKit may still include traffic influence. If time seems high,
        // use a distance-based heuristic as fallback (50 km/h average).
        let heuristicTime = fastest.distance / (50.0 * 1000.0 / 3600.0)
        return min(fastest.expectedTravelTime, heuristicTime)
    }
}
```

- [ ] **Step 2: Add the file to the Xcode project**

Check `project.yml` — if it uses `sources: - TrafficMenubar` (directory glob), the file is auto-included on next `xcodegen generate`. Run:

```bash
xcodegen generate
```

If not using XcodeGen, open the project in Xcode and add `BaselineFetcher.swift` to the TrafficMenubar target.

- [ ] **Step 3: Build and verify no errors**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Utilities/BaselineFetcher.swift TrafficMenubar.xcodeproj/project.pbxproj
git commit -m "feat: add BaselineFetcher service for no-traffic baseline times"
```

---

### Task 3: Replace TrafficMood initializers and update all callers (atomic)

This task replaces the two old `TrafficMood` initializers with the unified engine AND updates all callers in one atomic commit so the build never breaks.

**Files:**
- Modify: `TrafficMenubar/Views/DesignSystem.swift:13-39` (TrafficMood initializers)
- Modify: `TrafficMenubar/ViewModels/CommuteViewModel.swift:89-95` (mood property)
- Modify: `TrafficMenubar/Views/DeveloperSettingsView.swift:178-179` (mood preview)

- [ ] **Step 1: Replace the two existing initializers in DesignSystem.swift**

Remove the two initializers (lines 13-39) and replace with the unified initializer:

```swift
init(currentTime: TimeInterval,
     baselineTime: TimeInterval,
     segmentCongestion: [CongestionLevel]?,
     hasMajorIncidents: Bool) {

    // Major incidents bypass all duration logic
    if hasMajorIncidents {
        self = .heavy
        return
    }

    let delay = currentTime - baselineTime
    let delayMinutes = delay / 60.0
    let percentOver = baselineTime > 0 ? delay / baselineTime : 0

    // Primary mood from duration comparison (if/else-if, first match wins)
    var result: TrafficMood
    if delayMinutes < 3 {
        result = .clear
    } else if percentOver <= 0.15 && delayMinutes < 5 {
        result = .clear
    } else if percentOver > 0.30 && delayMinutes >= 10 {
        result = .heavy
    } else {
        result = .moderate
    }

    // Congestion bump: if >25% of segments are heavy/severe, bump up one level
    if let congestion = segmentCongestion, !congestion.isEmpty {
        let total = congestion.count
        let severeOrHeavy = congestion.filter { $0 == .severe || $0 == .heavy }.count
        let ratio = Double(severeOrHeavy) / Double(total)
        if ratio > 0.25 {
            switch result {
            case .clear: result = .moderate
            case .moderate: result = .heavy
            case .heavy, .unknown: break
            }
        }
    }

    self = result
}
```

- [ ] **Step 2: Replace the `mood` computed property in CommuteViewModel.swift**

Replace lines 89-95 with:

```swift
var mood: TrafficMood {
    guard let route = fastestRoute else { return .unknown }

    let baseline: TimeInterval
    switch settings.baselineCompareMode {
    case .typical:
        baseline = route.normalTravelTime
    case .bestCase:
        let persisted = direction == .toWork
            ? settings.baselineToWorkTime
            : settings.baselineToHomeTime
        baseline = persisted ?? route.normalTravelTime
    }

    let hasMajorIncidents = currentResult?.incidents.contains {
        $0.severity == .major || $0.severity == .severe
    } ?? false

    return TrafficMood(
        currentTime: route.travelTime,
        baselineTime: baseline,
        segmentCongestion: route.segmentCongestion,
        hasMajorIncidents: hasMajorIncidents
    )
}
```

- [ ] **Step 3: Replace the mood preview in DeveloperSettingsView.swift**

Replace lines 178-179:

```swift
let delay = max(0, Int(mockProvider.travelTimeMinutes - mockProvider.normalTimeMinutes))
let computedMood = TrafficMood(delayMinutes: delay, hasIncidents: mockProvider.includeIncidents)
```

With:

```swift
let currentTime = mockProvider.travelTimeMinutes * 60
let baselineTime = mockProvider.normalTimeMinutes * 60
let computedMood = TrafficMood(
    currentTime: currentTime,
    baselineTime: baselineTime,
    segmentCongestion: nil,
    hasMajorIncidents: mockProvider.includeIncidents && mockProvider.maxSeverity != .minor
)
let delay = max(0, Int(mockProvider.travelTimeMinutes - mockProvider.normalTimeMinutes))
```

The `delay` variable is still needed for the display text on line 181.

- [ ] **Step 4: Build and verify — all errors resolved**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit (single atomic commit)**

```bash
git add TrafficMenubar/Views/DesignSystem.swift TrafficMenubar/ViewModels/CommuteViewModel.swift TrafficMenubar/Views/DeveloperSettingsView.swift
git commit -m "feat: replace dual TrafficMood initializers with unified baseline engine

Update all callers: CommuteViewModel mood property now selects baseline
from settings, DeveloperSettingsView preview uses new initializer."
```

---

### Task 4: Update PopoverView delay display to use chosen baseline

**Files:**
- Modify: `TrafficMenubar/Views/PopoverView.swift:191-195` (moodBadge delay display)

- [ ] **Step 1: Replace the delay display in moodBadge**

Find this complete block (lines 191-195):

```swift
if let route = viewModel.fastestRoute, route.delayMinutes > 0 {
    Text("· +\(route.delayMinutes) min")
        .font(Design.moodFont(scale: fontScale))
        .foregroundColor(colorScheme == .dark ? mood.darkAccentColor : mood.lightTextColor)
}
```

Replace with:

```swift
if let route = viewModel.fastestRoute {
    let baseline: TimeInterval
    switch viewModel.settings.baselineCompareMode {
    case .typical:
        baseline = route.normalTravelTime
    case .bestCase:
        let persisted = viewModel.direction == .toWork
            ? viewModel.settings.baselineToWorkTime
            : viewModel.settings.baselineToHomeTime
        baseline = persisted ?? route.normalTravelTime
    }
    let delayMinutes = max(0, Int((route.travelTime - baseline) / 60))
    if delayMinutes > 0 {
        Text("· +\(delayMinutes) min")
            .font(Design.moodFont(scale: fontScale))
            .foregroundColor(colorScheme == .dark ? mood.darkAccentColor : mood.lightTextColor)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Views/PopoverView.swift
git commit -m "feat: use chosen baseline for delay display in popover mood badge"
```

---

### Task 5: Add Traffic Comparison section to PreferencesView

**Files:**
- Modify: `TrafficMenubar/Views/PreferencesView.swift`

- [ ] **Step 1: Add state for baseline fetching**

Add to the `@State` properties at the top of the struct (around line 13):

```swift
@State private var isFetchingBaseline = false
@State private var baselineFetchError: String?
```

- [ ] **Step 2: Add the Traffic Comparison section to generalTab**

Insert a new section after the "LOCATION" divider (after line 370) and before the "TRAFFIC PROVIDER" section:

```swift
// Traffic Comparison
VStack(alignment: .leading, spacing: 8) {
    Text("TRAFFIC COMPARISON")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
        .tracking(0.5)

    Picker("Compare to", selection: $settings.baselineCompareMode) {
        ForEach(BaselineCompareMode.allCases, id: \.self) { mode in
            Text(mode.displayName).tag(mode)
        }
    }
    .pickerStyle(.radioGroup)
    .font(.system(size: 13, design: .rounded))
    .foregroundColor(isDark ? .white.opacity(0.7) : .primary)

    if settings.effectiveMapboxKey != nil {
        Toggle("Use Mapbox for baseline", isOn: $settings.useMapboxBaseline)
            .font(.system(size: 13, design: .rounded))
            .foregroundColor(isDark ? .white.opacity(0.7) : .primary)
            .tint(TrafficMood.clear.darkAccentColor)
    }

    HStack(spacing: 10) {
        Button(action: fetchBaseline) {
            if isFetchingBaseline {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else {
                Text("Recalibrate")
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundColor(TrafficMood.clear.darkAccentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TrafficMood.clear.darkAccentColor.opacity(0.15))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(TrafficMood.clear.darkAccentColor.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .buttonStyle(.plain)
        .disabled(!settings.isConfigured || isFetchingBaseline)

        baselineSummaryText
    }
}

Divider().opacity(isDark ? 0.06 : 0.15)
```

- [ ] **Step 3: Add the baseline summary computed view**

Add as a new `@ViewBuilder` method in PreferencesView:

```swift
@ViewBuilder
private var baselineSummaryText: some View {
    if let error = baselineFetchError {
        Text(error)
            .font(.system(size: 10, design: .rounded))
            .foregroundColor(.orange)
    } else if let toWork = settings.baselineToWorkTime,
              let toHome = settings.baselineToHomeTime {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(toWork / 60)) min \u{2192} work, \(Int(toHome / 60)) min \u{2192} home")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
            if let fetchedAt = settings.baselineFetchedAt {
                Text("Set on \(fetchedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.3) : .secondary.opacity(0.6))
            }
        }
    } else {
        Text("No baseline set")
            .font(.system(size: 10, design: .rounded))
            .foregroundColor(isDark ? .white.opacity(0.35) : .secondary)
    }
}
```

- [ ] **Step 4: Add the fetchBaseline method**

Add alongside the other geocoding methods:

```swift
private func fetchBaseline() {
    guard let home = settings.homeCoordinate,
          let work = settings.workCoordinate else { return }

    isFetchingBaseline = true
    baselineFetchError = nil
    Task {
        do {
            let apiKey = settings.useMapboxBaseline ? settings.effectiveMapboxKey : nil
            let result = try await BaselineFetcher.fetch(
                home: home,
                work: work,
                mapboxAPIKey: apiKey
            )
            settings.baselineToWorkTime = result.toWorkTime
            settings.baselineToHomeTime = result.toHomeTime
            settings.baselineFetchedAt = Date()
            baselineFetchError = nil
        } catch {
            baselineFetchError = "Baseline not available — try again"
        }
        isFetchingBaseline = false
    }
}
```

- [ ] **Step 5: Clear stale baselines on address change and re-fetch on geocode success**

In the existing `geocodeHome()` method (line 647-661), add `settings.clearBaselines()` at the start of the method (before the Task), so stale baselines are cleared immediately when the user re-geocodes. Then after `settings.homeCoordinate = coord` succeeds, add:

```swift
if settings.isConfigured {
    fetchBaseline()
}
```

Do the same in `geocodeWork()`:
- Add `settings.clearBaselines()` at the start
- Add the `fetchBaseline()` trigger after coordinate is set

- [ ] **Step 6: Increase window height to accommodate new section**

The window is currently 420x420 (line 59). Change to use a minimum height with scrolling support:

```swift
.frame(width: 420, minHeight: 420, maxHeight: 520)
```

- [ ] **Step 7: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add TrafficMenubar/Views/PreferencesView.swift
git commit -m "feat: add Traffic Comparison section to Preferences with baseline fetching"
```

---

### Task 6: Re-fetch baseline on Mapbox key change

**Files:**
- Modify: `TrafficMenubar/Views/PreferencesView.swift`

The spec requires baseline re-fetch when the Mapbox key changes. Currently, the "Save Key" and "Remove Key" buttons in PreferencesView update `settings.mapboxAPIKey` and `settings.mapboxKeySource`. We need to trigger a baseline re-fetch after these changes.

- [ ] **Step 1: Add baseline re-fetch after Mapbox key save**

In the `mapboxBYOKInputCard` view (around line 525-529), after the "Save Key" button action saves the key:

```swift
settings.setMapboxKey(byokKeyInput.trimmingCharacters(in: .whitespaces), source: "byok")
byokKeyInput = ""
showingBYOKInput = false
```

Add after `showingBYOKInput = false`:

```swift
if settings.isConfigured {
    fetchBaseline()
}
```

- [ ] **Step 2: Clear and re-fetch baseline after Mapbox key removal**

In the `mapboxActiveCard` view (around line 608-610), after the "Remove Key" button action:

```swift
settings.clearMapboxKey()
```

Add after `settings.clearMapboxKey()`:

```swift
settings.clearBaselines()
if settings.isConfigured {
    fetchBaseline()
}
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/PreferencesView.swift
git commit -m "feat: re-fetch baseline on Mapbox key change"
```

---

### Task 7: Expose baseline values in DeveloperSettingsView

**Files:**
- Modify: `TrafficMenubar/Views/DeveloperSettingsView.swift`

The spec requires exposing baseline values in developer settings for testing/override.

- [ ] **Step 1: Add baseline display after the mood preview section**

After the existing mood preview section (around line 190, after the congestion toggle), add a new section:

```swift
Divider().opacity(0.06)

VStack(alignment: .leading, spacing: 8) {
    Text("Baseline (persisted)")
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(primaryText)

    let settings = SettingsStore.shared
    HStack {
        Text("Compare mode:")
            .font(.system(size: 12))
            .foregroundColor(secondaryText)
        Text(settings.baselineCompareMode.displayName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.orange)
    }

    if let toWork = settings.baselineToWorkTime {
        HStack {
            Text("To work baseline:")
                .font(.system(size: 12))
                .foregroundColor(secondaryText)
            Text("\(Int(toWork / 60)) min")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
        }
    }

    if let toHome = settings.baselineToHomeTime {
        HStack {
            Text("To home baseline:")
                .font(.system(size: 12))
                .foregroundColor(secondaryText)
            Text("\(Int(toHome / 60)) min")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
        }
    }

    if let fetchedAt = settings.baselineFetchedAt {
        Text("Fetched: \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.system(size: 11))
            .foregroundColor(secondaryText)
    } else {
        Text("No baseline set")
            .font(.system(size: 11))
            .foregroundColor(secondaryText.opacity(0.6))
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Views/DeveloperSettingsView.swift
git commit -m "feat: expose baseline values in developer settings panel"
```

---

### Task 8: Verify end-to-end with developer settings

**Files:**
- No new modifications — manual verification

- [ ] **Step 1: Build and run the app**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Verify in developer mode**

Open the app. Enable Developer Mode in Preferences > General. Open Developer Settings.

Test the following scenarios using the mock sliders:
1. Travel time = 25 min, Normal time = 22 min (14% over, 3 min delay) → Should be GREEN (under 3 min floor)
2. Travel time = 30 min, Normal time = 22 min (36% over, 8 min delay) → Should be AMBER (>30% but <10 min delay)
3. Travel time = 40 min, Normal time = 22 min (82% over, 18 min delay) → Should be RED (both thresholds hit)
4. Travel time = 22 min, Normal time = 22 min, Incidents ON with major severity → Should be RED (incidents bypass)

- [ ] **Step 3: Verify Preferences UI**

Open Preferences > General tab:
1. "Traffic Comparison" section should appear with radio picker and Recalibrate button
2. If no Mapbox key: "Use Mapbox for baseline" checkbox should be hidden
3. If no baseline set: summary should say "No baseline set"
4. Click Recalibrate — should attempt fetch and update summary
5. Toggle between "Best case" and "Typical traffic" — mood should update on next poll

- [ ] **Step 4: Verify baseline re-fetch triggers**

1. Change home address and re-geocode — baselines should clear then re-fetch
2. Add a Mapbox key — baselines should re-fetch using Mapbox
3. Remove the Mapbox key — baselines should clear and re-fetch using MapKit

- [ ] **Step 5: Commit any fixes discovered during testing**

```bash
git add -A
git commit -m "fix: address issues found during end-to-end verification"
```
