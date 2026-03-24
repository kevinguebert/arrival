# Developer Settings Pane Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a developer settings window that lets you force app states, override route data, inject incidents, and tweak design values — all reflected in real-time in the popover and menu bar.

**Architecture:** A `MockTrafficProvider` replaces the real provider when dev mode is active. A `DevDesignOverrides` environment object controls visual tweaks. The `CommuteViewModel` gains enable/disable dev mode methods that swap the provider and pause/resume polling.

**Tech Stack:** SwiftUI, Combine, macOS 13+

**Spec:** `docs/superpowers/specs/2026-03-24-developer-settings-pane-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `TrafficMenubar/Providers/MockTrafficProvider.swift` | Observable mock that builds `RouteResult` from dev-controlled values |
| `TrafficMenubar/ViewModels/DevDesignOverrides.swift` | Observable design overrides (mood force, font scale) + environment key |
| `TrafficMenubar/Views/DeveloperSettingsView.swift` | The developer settings window UI |

### Modified Files
| File | Changes |
|------|---------|
| `TrafficMenubar/Utilities/SettingsStore.swift` | Add `developerModeEnabled` property |
| `TrafficMenubar/ViewModels/CommuteViewModel.swift` | `provider` → `private(set) var`, add `isDevMode`, `enableDevMode()`, `disableDevMode()`, `updateFromMock()` |
| `TrafficMenubar/Views/DesignSystem.swift` | Refactor static fonts to support scale multiplier |
| `TrafficMenubar/Views/PopoverView.swift` | Read `DevDesignOverrides` from environment, apply font scale, add DEV badge |
| `TrafficMenubar/Views/IncidentBannerView.swift` | Update `Design.captionFont` references to use scaled function calls |
| `TrafficMenubar/Views/PreferencesView.swift` | Add Developer Mode toggle + Open Developer Settings button to General tab |
| `TrafficMenubar/TrafficMenubarApp.swift` | Register developer window scene, add `OpenDevWindowAction` environment key, inject `DevDesignOverrides` |

---

### Task 1: Add `developerModeEnabled` to SettingsStore

**Files:**
- Modify: `TrafficMenubar/Utilities/SettingsStore.swift`

- [ ] **Step 1: Add the published property with UserDefaults persistence**

In `SettingsStore`, add after the `launchAtLogin` property (line 69):

```swift
@Published var developerModeEnabled: Bool {
    didSet { UserDefaults.standard.set(developerModeEnabled, forKey: "developerModeEnabled") }
}
```

- [ ] **Step 2: Initialize from UserDefaults**

In `private init()`, after `self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")` (line 111), add:

```swift
self.developerModeEnabled = defaults.bool(forKey: "developerModeEnabled")
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Utilities/SettingsStore.swift
git commit -m "feat: add developerModeEnabled setting to SettingsStore"
```

---

### Task 2: Create MockTrafficProvider

**Files:**
- Create: `TrafficMenubar/Providers/MockTrafficProvider.swift`

- [ ] **Step 1: Create the file with all mock state and route building logic**

```swift
import Foundation
import Combine

@MainActor
final class MockTrafficProvider: ObservableObject, TrafficProvider {
    // MARK: - Configurable State

    @Published var travelTimeMinutes: Double = 25
    @Published var normalTimeMinutes: Double = 25
    @Published var includeIncidents: Bool = false
    @Published var incidentCount: Int = 2
    @Published var maxSeverity: IncidentSeverity = .major

    // MARK: - Sample Data

    static let samplePolyline: [Coordinate] = [
        Coordinate(latitude: 37.7749, longitude: -122.4194),
        Coordinate(latitude: 37.7755, longitude: -122.4170),
        Coordinate(latitude: 37.7765, longitude: -122.4145),
        Coordinate(latitude: 37.7780, longitude: -122.4120),
        Coordinate(latitude: 37.7800, longitude: -122.4100),
        Coordinate(latitude: 37.7820, longitude: -122.4085),
        Coordinate(latitude: 37.7845, longitude: -122.4070),
        Coordinate(latitude: 37.7870, longitude: -122.4060),
        Coordinate(latitude: 37.7895, longitude: -122.4055),
        Coordinate(latitude: 37.7920, longitude: -122.4050),
        Coordinate(latitude: 37.7945, longitude: -122.4048),
        Coordinate(latitude: 37.7970, longitude: -122.4045),
        Coordinate(latitude: 37.7990, longitude: -122.4040),
        Coordinate(latitude: 37.8010, longitude: -122.4035),
        Coordinate(latitude: 37.8030, longitude: -122.4025),
        Coordinate(latitude: 37.8050, longitude: -122.4010),
        Coordinate(latitude: 37.8065, longitude: -122.3995),
        Coordinate(latitude: 37.8080, longitude: -122.3975),
        Coordinate(latitude: 37.8090, longitude: -122.3955),
        Coordinate(latitude: 37.8095, longitude: -122.3935),
    ]

    // MARK: - TrafficProvider Conformance

    func fetchRoute(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
        buildRoute()
    }

    // MARK: - Route Building

    func buildRoute() -> RouteResult {
        let travelTime = travelTimeMinutes * 60
        let normalTime = normalTimeMinutes * 60

        let incidents: [TrafficIncident]
        if includeIncidents {
            incidents = generateIncidents()
        } else {
            incidents = []
        }

        return RouteResult(
            travelTime: travelTime,
            normalTravelTime: normalTime,
            eta: Date().addingTimeInterval(travelTime),
            incidents: incidents,
            routePolyline: Self.samplePolyline
        )
    }

    private func generateIncidents() -> [TrafficIncident] {
        let templates: [(IncidentSeverity, String)] = [
            (.minor, "Minor slowdown ahead"),
            (.major, "Construction on main route"),
            (.severe, "Major accident — expect significant delays"),
        ]

        let filtered = templates.filter { severity, _ in
            switch maxSeverity {
            case .minor: return severity == .minor
            case .major: return severity == .minor || severity == .major
            case .severe: return true
            }
        }

        let count = min(incidentCount, filtered.count)
        return (0..<count).map { index in
            let (severity, description) = filtered[index % filtered.count]
            let polylineIndex = min(index * 5 + 3, Self.samplePolyline.count - 1)
            return TrafficIncident(
                description: description,
                severity: severity,
                location: Self.samplePolyline[polylineIndex]
            )
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Providers/MockTrafficProvider.swift
git commit -m "feat: add MockTrafficProvider for developer settings"
```

---

### Task 3: Add dev mode support to CommuteViewModel

**Files:**
- Modify: `TrafficMenubar/ViewModels/CommuteViewModel.swift`

- [ ] **Step 1: Change `provider` from `private let` to `private(set) var`**

Change line 15 from:
```swift
    private let provider: TrafficProvider
```
to:
```swift
    private(set) var provider: TrafficProvider
```

- [ ] **Step 2: Add `isDevMode` published property**

After the `directionOverride` property (line 11), add:

```swift
    @Published var isDevMode = false
```

- [ ] **Step 3: Add `enableDevMode()` method**

After the `setDirectionOverride` method (lines 45-48), add:

```swift
    func enableDevMode(mockProvider: MockTrafficProvider) {
        stopPolling()
        provider = mockProvider
        isDevMode = true
    }
```

- [ ] **Step 4: Add `disableDevMode()` method**

After `enableDevMode`, add:

```swift
    func disableDevMode() {
        provider = MapKitProvider()
        isDevMode = false
        startPolling()
    }
```

- [ ] **Step 5: Add `updateFromMock()` method**

After `disableDevMode`, add:

```swift
    func updateFromMock(route: RouteResult?, direction: CommuteDirection, consecutiveFailures: Int, isLoading: Bool) {
        self.currentRoute = route
        self.direction = direction
        self.consecutiveFailures = consecutiveFailures
        self.isLoading = isLoading
        self.lastUpdated = route != nil ? Date() : nil
    }
```

- [ ] **Step 6: Build and verify**

Run: `xcodebuild -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 7: Commit**

```bash
git add TrafficMenubar/ViewModels/CommuteViewModel.swift
git commit -m "feat: add dev mode support to CommuteViewModel"
```

---

### Task 4: Create DevDesignOverrides with environment key

**Files:**
- Create: `TrafficMenubar/ViewModels/DevDesignOverrides.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import Combine

final class DevDesignOverrides: ObservableObject {
    @Published var moodOverride: TrafficMood?
    @Published var fontScale: CGFloat = 1.0
}

// MARK: - Environment Key

struct DevDesignOverridesKey: EnvironmentKey {
    static let defaultValue: DevDesignOverrides? = nil
}

extension EnvironmentValues {
    var devDesignOverrides: DevDesignOverrides? {
        get { self[DevDesignOverridesKey.self] }
        set { self[DevDesignOverridesKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/ViewModels/DevDesignOverrides.swift
git commit -m "feat: add DevDesignOverrides with environment key"
```

---

### Task 5: Refactor DesignSystem for font scaling

**Files:**
- Modify: `TrafficMenubar/Views/DesignSystem.swift`
- Modify: `TrafficMenubar/Views/PopoverView.swift`
- Modify: `TrafficMenubar/Views/IncidentBannerView.swift`

- [ ] **Step 1: Replace static Font properties with scalable helpers**

Replace the Typography section (lines 77-83) of the `Design` enum:

```swift
    // Typography
    static let heroTimeFont: Font = .system(size: 48, weight: .bold, design: .rounded)
    static let heroUnitFont: Font = .system(size: 20, weight: .medium, design: .rounded)
    static let etaValueFont: Font = .system(size: 22, weight: .semibold, design: .rounded)
    static let labelFont: Font = .system(size: 11, weight: .semibold, design: .rounded)
    static let captionFont: Font = .system(size: 11, weight: .regular, design: .rounded)
    static let moodFont: Font = .system(size: 12, weight: .medium, design: .rounded)
```

with:

```swift
    // Typography — base sizes
    static let heroTimeSize: CGFloat = 48
    static let heroUnitSize: CGFloat = 20
    static let etaValueSize: CGFloat = 22
    static let labelSize: CGFloat = 11
    static let captionSize: CGFloat = 11
    static let moodSize: CGFloat = 12

    // Scaled font helpers
    static func heroTimeFont(scale: CGFloat = 1.0) -> Font {
        .system(size: heroTimeSize * scale, weight: .bold, design: .rounded)
    }
    static func heroUnitFont(scale: CGFloat = 1.0) -> Font {
        .system(size: heroUnitSize * scale, weight: .medium, design: .rounded)
    }
    static func etaValueFont(scale: CGFloat = 1.0) -> Font {
        .system(size: etaValueSize * scale, weight: .semibold, design: .rounded)
    }
    static func labelFont(scale: CGFloat = 1.0) -> Font {
        .system(size: labelSize * scale, weight: .semibold, design: .rounded)
    }
    static func captionFont(scale: CGFloat = 1.0) -> Font {
        .system(size: captionSize * scale, weight: .regular, design: .rounded)
    }
    static func moodFont(scale: CGFloat = 1.0) -> Font {
        .system(size: moodSize * scale, weight: .medium, design: .rounded)
    }
```

- [ ] **Step 2: Build — expect errors in PopoverView**

Run: `xcodebuild -scheme TrafficMenubar build 2>&1 | grep "error:"`
Expected: Errors where `Design.heroTimeFont` etc. are used as properties instead of function calls.

- [ ] **Step 3: Update PopoverView to use function calls with default scale**

In `PopoverView.swift`, add the environment property at the top of the struct (after line 6):

```swift
    @Environment(\.devDesignOverrides) private var designOverrides
```

Add a computed helper after `refreshPulse` (after line 6):

```swift
    private var fontScale: CGFloat {
        designOverrides?.fontScale ?? 1.0
    }
```

Then replace all `Design.<font>` property references with function calls using `fontScale`:

- `Design.heroTimeFont` → `Design.heroTimeFont(scale: fontScale)`
- `Design.heroUnitFont` → `Design.heroUnitFont(scale: fontScale)`
- `Design.etaValueFont` → `Design.etaValueFont(scale: fontScale)`
- `Design.labelFont` → `Design.labelFont(scale: fontScale)`
- `Design.captionFont` → `Design.captionFont(scale: fontScale)`
- `Design.moodFont` → `Design.moodFont(scale: fontScale)`

Replace **every** occurrence of `Design.<fontName>` with `Design.<fontName>(scale: fontScale)` throughout `PopoverView.swift`. All 13 occurrences:
- Line 67: `Design.labelFont` (ARRIVE BY label)
- Line 72: `Design.etaValueFont` (ETA value)
- Line 76: `Design.etaValueFont` (ETA placeholder)
- Line 91: `Design.labelFont` (direction label)
- Line 102: `Design.heroTimeFont` (hero time)
- Line 106: `Design.heroUnitFont` (hero unit "min")
- Line 121: `Design.moodFont` (mood phrase)
- Line 125: `Design.moodFont` (delay text)
- Line 169: `Design.captionFont` (update timestamp)
- Line 178: `Design.captionFont` (offline text)
- Line 212: `Design.captionFont` (loading state subtitle)
- Line 229: `Design.captionFont` (error state subtitle)
- Line 246: `Design.captionFont` (empty state subtitle)

- [ ] **Step 4: Update IncidentBannerView to use scaled font calls**

In `IncidentBannerView.swift`, add the environment property at the top of the struct:

```swift
    @Environment(\.devDesignOverrides) private var designOverrides

    private var fontScale: CGFloat {
        designOverrides?.fontScale ?? 1.0
    }
```

Then replace:
- Line 28: `Design.captionFont` → `Design.captionFont(scale: fontScale)` (incident description)
- Line 37: `Design.captionFont` → `Design.captionFont(scale: fontScale)` ("+ N more" text)

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 6: Commit**

```bash
git add TrafficMenubar/Views/DesignSystem.swift TrafficMenubar/Views/PopoverView.swift TrafficMenubar/Views/IncidentBannerView.swift
git commit -m "refactor: make Design fonts scalable for dev mode font scaling"
```

---

### Task 6: Add DEV badge and mood override to PopoverView

**Files:**
- Modify: `TrafficMenubar/Views/PopoverView.swift`

- [ ] **Step 1: Update the `mood` computed property to respect mood override**

Replace the existing `mood` computed property:

```swift
    private var mood: TrafficMood {
        guard let route = viewModel.currentRoute else { return .unknown }
        return TrafficMood(delayMinutes: route.delayMinutes, hasIncidents: route.hasIncidents)
    }
```

with:

```swift
    private var mood: TrafficMood {
        if let override = designOverrides?.moodOverride {
            return override
        }
        guard let route = viewModel.currentRoute else { return .unknown }
        return TrafficMood(delayMinutes: route.delayMinutes, hasIncidents: route.hasIncidents)
    }
```

- [ ] **Step 2: Add DEV badge to the footer section**

In `footerSection`, after the offline error `HStack` block and before `Spacer()`, add:

```swift
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
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/PopoverView.swift
git commit -m "feat: add DEV badge and mood override support to PopoverView"
```

---

### Task 7: Create DeveloperSettingsView

**Files:**
- Create: `TrafficMenubar/Views/DeveloperSettingsView.swift`

- [ ] **Step 1: Create the full developer settings view**

```swift
import SwiftUI

struct DeveloperSettingsView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @ObservedObject var mockProvider: MockTrafficProvider
    @ObservedObject var designOverrides: DevDesignOverrides

    @State private var forcedState: ForcedAppState = .normal
    @State private var forcedDirection: CommuteDirection = .toWork
    @State private var forcedFailures: Int = 0

    enum ForcedAppState: String, CaseIterable {
        case normal = "Normal"
        case loading = "Loading"
        case error = "Error"
        case empty = "Empty"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                masterToggle
                if viewModel.isDevMode {
                    appStateSection
                    routeDataSection
                    incidentsSection
                    designOverridesSection
                    quickPresetsSection
                }
            }
            .padding(20)
        }
        .frame(width: 400, minHeight: 500)
        .onChange(of: forcedState) { _ in applyState() }
        .onChange(of: forcedDirection) { _ in applyState() }
        .onChange(of: forcedFailures) { _ in applyState() }
        .onChange(of: mockProvider.travelTimeMinutes) { _ in applyState() }
        .onChange(of: mockProvider.normalTimeMinutes) { _ in applyState() }
        .onChange(of: mockProvider.includeIncidents) { _ in applyState() }
        .onChange(of: mockProvider.incidentCount) { _ in applyState() }
        .onChange(of: mockProvider.maxSeverity) { _ in applyState() }
    }

    // MARK: - Master Toggle

    @ViewBuilder
    private var masterToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.orange)
                    Text(viewModel.isDevMode ? "Dev Mode Active" : "Dev Mode Off")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                if viewModel.isDevMode {
                    Text("Polling paused · Mock data in use")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { viewModel.isDevMode },
                set: { enabled in
                    if enabled {
                        viewModel.enableDevMode(mockProvider: mockProvider)
                        applyState()
                    } else {
                        viewModel.disableDevMode()
                    }
                }
            ))
            .toggleStyle(.switch)
            .tint(.orange)
        }
        .padding(12)
        .background(viewModel.isDevMode ? Color.orange.opacity(0.08) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.isDevMode ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - App State

    @ViewBuilder
    private var appStateSection: some View {
        devSection("App State") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Force state")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $forcedState) {
                        ForEach(ForcedAppState.allCases, id: \.self) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }

                HStack {
                    Text("Direction")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $forcedDirection) {
                        Text("To Work").tag(CommuteDirection.toWork)
                        Text("To Home").tag(CommuteDirection.toHome)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                HStack {
                    Text("Consecutive failures")
                        .font(.system(size: 12))
                    Spacer()
                    Stepper("\(forcedFailures)", value: $forcedFailures, in: 0...10)
                        .frame(width: 100)
                }
            }
        }
    }

    // MARK: - Route Data

    @ViewBuilder
    private var routeDataSection: some View {
        devSection("Route Data") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Travel time")
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(Int(mockProvider.travelTimeMinutes)) min")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $mockProvider.travelTimeMinutes, in: 1...120, step: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Normal time (baseline)")
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(Int(mockProvider.normalTimeMinutes)) min")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $mockProvider.normalTimeMinutes, in: 1...120, step: 1)
                }

                let delay = max(0, Int(mockProvider.travelTimeMinutes - mockProvider.normalTimeMinutes))
                let computedMood = TrafficMood(delayMinutes: delay, hasIncidents: mockProvider.includeIncidents)
                HStack {
                    Text("Delay: +\(delay) min")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("\(computedMood.moodEmoji) \(computedMood.moodPhrase)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Incidents

    @ViewBuilder
    private var incidentsSection: some View {
        devSection("Incidents") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Include incidents", isOn: $mockProvider.includeIncidents)
                    .font(.system(size: 12))

                if mockProvider.includeIncidents {
                    HStack {
                        Text("Number of incidents")
                            .font(.system(size: 12))
                        Spacer()
                        Stepper("\(mockProvider.incidentCount)", value: $mockProvider.incidentCount, in: 1...3)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Max severity")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $mockProvider.maxSeverity) {
                            Text("Minor").tag(IncidentSeverity.minor)
                            Text("Major").tag(IncidentSeverity.major)
                            Text("Severe").tag(IncidentSeverity.severe)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }
            }
        }
    }

    // MARK: - Design Overrides

    @ViewBuilder
    private var designOverridesSection: some View {
        devSection("Design Overrides") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Force mood")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { designOverrides.moodOverride },
                        set: { designOverrides.moodOverride = $0 }
                    )) {
                        Text("Auto").tag(TrafficMood?.none)
                        Text("☀️").tag(TrafficMood?.some(.clear))
                        Text("🌤").tag(TrafficMood?.some(.moderate))
                        Text("🌧").tag(TrafficMood?.some(.heavy))
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Font scale")
                            .font(.system(size: 12))
                        Spacer()
                        Text(String(format: "%.1f×", designOverrides.fontScale))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $designOverrides.fontScale, in: 0.5...2.0, step: 0.1)
                }
            }
        }
    }

    // MARK: - Quick Presets

    @ViewBuilder
    private var quickPresetsSection: some View {
        devSection("Quick Presets") {
            let presets: [(String, () -> Void)] = [
                ("☀️ Clear roads", {
                    mockProvider.travelTimeMinutes = 25
                    mockProvider.normalTimeMinutes = 25
                    mockProvider.includeIncidents = false
                    forcedState = .normal
                    forcedFailures = 0
                }),
                ("🌤 Moderate", {
                    mockProvider.travelTimeMinutes = 35
                    mockProvider.normalTimeMinutes = 25
                    mockProvider.includeIncidents = false
                    forcedState = .normal
                    forcedFailures = 0
                }),
                ("🌧 Heavy + incidents", {
                    mockProvider.travelTimeMinutes = 55
                    mockProvider.normalTimeMinutes = 25
                    mockProvider.includeIncidents = true
                    mockProvider.incidentCount = 2
                    mockProvider.maxSeverity = .severe
                    forcedState = .normal
                    forcedFailures = 0
                }),
                ("💤 Empty state", {
                    forcedState = .empty
                    forcedFailures = 0
                }),
                ("⚡ Loading", {
                    forcedState = .loading
                    forcedFailures = 0
                }),
                ("☁️ Offline", {
                    forcedState = .error
                    forcedFailures = 3
                }),
            ]

            FlowLayout(spacing: 6) {
                ForEach(presets, id: \.0) { label, action in
                    Button(action: action) {
                        Text(label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func devSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.0)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func applyState() {
        guard viewModel.isDevMode else { return }

        switch forcedState {
        case .normal:
            let route = mockProvider.buildRoute()
            viewModel.updateFromMock(
                route: route,
                direction: forcedDirection,
                consecutiveFailures: forcedFailures,
                isLoading: false
            )
        case .loading:
            viewModel.updateFromMock(
                route: nil,
                direction: forcedDirection,
                consecutiveFailures: 0,
                isLoading: true
            )
        case .error:
            viewModel.updateFromMock(
                route: nil,
                direction: forcedDirection,
                consecutiveFailures: max(3, forcedFailures),
                isLoading: false
            )
        case .empty:
            viewModel.updateFromMock(
                route: nil,
                direction: forcedDirection,
                consecutiveFailures: 0,
                isLoading: false
            )
        }
    }
}

// MARK: - FlowLayout

/// Simple wrapping layout for preset buttons.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (offsets, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Views/DeveloperSettingsView.swift
git commit -m "feat: add DeveloperSettingsView with all controls and presets"
```

---

### Task 8: Add Developer Mode toggle to PreferencesView

**Files:**
- Modify: `TrafficMenubar/Views/PreferencesView.swift`

- [ ] **Step 1: Add the environment action for opening dev window**

At the top of `PreferencesView` struct (after line 9), add:

```swift
    @Environment(\.openDevWindow) private var openDevWindow
```

- [ ] **Step 2: Add Developer section to the General tab**

In the `generalTab` computed property, after the "Traffic Provider" `Section` block (after line 188), add:

```swift
            Section("Developer") {
                Toggle("Developer Mode", isOn: $settings.developerModeEnabled)
                if settings.developerModeEnabled {
                    Button("Open Developer Settings") {
                        openDevWindow()
                    }
                }
                Text("Enables mock data controls for testing UI states.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
```

- [ ] **Step 3: Build — expect error for missing `openDevWindow` environment key**

This is expected. It will be wired up in Task 9 when we update `TrafficMenubarApp.swift`.

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/PreferencesView.swift
git commit -m "feat: add Developer Mode toggle to General preferences tab"
```

---

### Task 9: Wire everything together in TrafficMenubarApp

**Files:**
- Modify: `TrafficMenubar/TrafficMenubarApp.swift`

- [ ] **Step 1: Add state objects for mock provider and design overrides**

In `TrafficMenubarApp` struct, after the `hasCheckedFirstLaunch` state (line 7), add:

```swift
    @StateObject private var mockProvider = MockTrafficProvider()
    @StateObject private var designOverrides = DevDesignOverrides()
```

- [ ] **Step 2: Inject DevDesignOverrides into the PopoverView environment**

Wrap the existing `.environment(\.openPreferencesWindow, ...)` modifier on `PopoverView` so it also includes the design overrides. After the existing `.environment` line (line 13), add:

```swift
                .environment(\.devDesignOverrides, designOverrides)
                .environmentObject(designOverrides)
```

- [ ] **Step 3: Register the Developer window scene**

After the Preferences `Window` scene (after line 36), add:

```swift
        Window("Developer Settings", id: "developer") {
            DeveloperSettingsView(
                viewModel: viewModel,
                mockProvider: mockProvider,
                designOverrides: designOverrides
            )
        }
        .defaultSize(width: 400, height: 600)
        .windowResizability(.contentMinSize)
```

- [ ] **Step 4: Add OpenDevWindowAction environment key**

After the existing `OpenPreferencesKey` / `EnvironmentValues` extension (after line 55), add:

```swift
struct OpenDevWindowAction {
    let action: () -> Void
    func callAsFunction() { action() }
}

struct OpenDevWindowKey: EnvironmentKey {
    static let defaultValue = OpenDevWindowAction { }
}

extension EnvironmentValues {
    var openDevWindow: OpenDevWindowAction {
        get { self[OpenDevWindowKey.self] }
        set { self[OpenDevWindowKey.self] = newValue }
    }
}
```

- [ ] **Step 5: Inject the OpenDevWindowAction into PreferencesView**

Update the Preferences `Window` scene to inject the dev window action. Change:

```swift
        Window("Preferences", id: "preferences") {
            PreferencesView(settings: viewModel.settings)
        }
```

to:

```swift
        Window("Preferences", id: "preferences") {
            PreferencesView(settings: viewModel.settings)
                .environment(\.openDevWindow, OpenDevWindowAction { [self] in
                    openWindow(id: "developer")
                    NSApp.activate(ignoringOtherApps: true)
                })
        }
```

- [ ] **Step 6: Build and verify the entire app compiles**

Run: `xcodebuild -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 7: Commit**

```bash
git add TrafficMenubar/TrafficMenubarApp.swift
git commit -m "feat: wire developer window, design overrides, and environment keys"
```

---

### Task 10: Manual smoke test

- [ ] **Step 1: Launch the app**

Run: `xcodebuild -scheme TrafficMenubar build && open ./build/Build/Products/Debug/TrafficMenubar.app` (or launch from Xcode)

- [ ] **Step 2: Enable Developer Mode**

1. Click menu bar item → ellipsis → Open Preferences
2. Go to General tab
3. Toggle "Developer Mode" on
4. Click "Open Developer Settings"

- [ ] **Step 3: Test quick presets**

Click each quick preset button and verify the popover updates:
- ☀️ Clear roads → green mood, ~25 min, no incidents
- 🌤 Moderate → amber mood, ~35 min, "+10 min" delay
- 🌧 Heavy + incidents → red mood, ~55 min, incident banner visible
- 💤 Empty state → "Where to?" empty state
- ⚡ Loading → "Scouting the roads..." loading state
- ☁️ Offline → "Lost signal" error state with orange "Offline" badge

- [ ] **Step 4: Test sliders**

Move the travel time slider and verify menu bar text updates in real-time.

- [ ] **Step 5: Test design overrides**

- Force mood to 🌧 with a clear-roads data setup — verify heavy mood colors show despite no delay
- Change font scale to 1.5× — verify popover text grows
- Reset font scale to 1.0×

- [ ] **Step 6: Test DEV badge**

Verify the orange "DEV" badge appears in the popover footer when dev mode is active.

- [ ] **Step 7: Disable dev mode**

Toggle dev mode off in the developer window. Verify polling resumes and real data appears.

- [ ] **Step 8: Commit any fixes if needed**

```bash
git add -A && git commit -m "fix: address smoke test findings"
```
