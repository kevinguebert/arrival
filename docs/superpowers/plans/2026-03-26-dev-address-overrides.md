# Dev Address Overrides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add developer address override fields so devs can test real routes for different cities without changing their actual addresses.

**Architecture:** New persisted dev address properties in SettingsStore with `effective*` computed properties that transparently return dev or real values. All consumers switch to reading effective properties. New UI section in DeveloperSettingsView mirrors the existing address geocoding UX.

**Tech Stack:** Swift, SwiftUI, CoreLocation (CLGeocoder via existing GeocodingService)

---

### Task 1: Add dev address properties to SettingsStore

**Files:**
- Modify: `TrafficMenubar/Utilities/SettingsStore.swift`

- [ ] **Step 1: Add the new persisted properties after the existing `developerModeEnabled` property (line ~97)**

Add these properties after `developerModeEnabled`:

```swift
@Published var devAddressOverrideEnabled: Bool {
    didSet { UserDefaults.standard.set(devAddressOverrideEnabled, forKey: "devAddressOverrideEnabled") }
}
@Published var devHomeAddress: String {
    didSet { UserDefaults.standard.set(devHomeAddress, forKey: "devHomeAddress") }
}
@Published var devWorkAddress: String {
    didSet { UserDefaults.standard.set(devWorkAddress, forKey: "devWorkAddress") }
}
@Published var devHomeCoordinate: Coordinate? {
    didSet {
        if let coord = devHomeCoordinate {
            UserDefaults.standard.set(coord.latitude, forKey: "devHomeLatitude")
            UserDefaults.standard.set(coord.longitude, forKey: "devHomeLongitude")
        } else {
            UserDefaults.standard.removeObject(forKey: "devHomeLatitude")
            UserDefaults.standard.removeObject(forKey: "devHomeLongitude")
        }
    }
}
@Published var devWorkCoordinate: Coordinate? {
    didSet {
        if let coord = devWorkCoordinate {
            UserDefaults.standard.set(coord.latitude, forKey: "devWorkLatitude")
            UserDefaults.standard.set(coord.longitude, forKey: "devWorkLongitude")
        } else {
            UserDefaults.standard.removeObject(forKey: "devWorkLatitude")
            UserDefaults.standard.removeObject(forKey: "devWorkLongitude")
        }
    }
}
```

- [ ] **Step 2: Initialize the new properties in `init()` (after the `developerModeEnabled` initialization around line ~201)**

Add after `self.developerModeEnabled = defaults.bool(forKey: "developerModeEnabled")`:

```swift
self.devAddressOverrideEnabled = defaults.bool(forKey: "devAddressOverrideEnabled")
self.devHomeAddress = defaults.string(forKey: "devHomeAddress") ?? ""
self.devWorkAddress = defaults.string(forKey: "devWorkAddress") ?? ""

if defaults.object(forKey: "devHomeLatitude") != nil {
    self.devHomeCoordinate = Coordinate(
        latitude: defaults.double(forKey: "devHomeLatitude"),
        longitude: defaults.double(forKey: "devHomeLongitude")
    )
} else {
    self.devHomeCoordinate = nil
}

if defaults.object(forKey: "devWorkLatitude") != nil {
    self.devWorkCoordinate = Coordinate(
        latitude: defaults.double(forKey: "devWorkLatitude"),
        longitude: defaults.double(forKey: "devWorkLongitude")
    )
} else {
    self.devWorkCoordinate = nil
}
```

- [ ] **Step 3: Add the effective computed properties and update `isConfigured`**

Add these computed properties after the existing `effectiveMapboxKey` (around line ~143):

```swift
private var devOverrideActive: Bool {
    developerModeEnabled && devAddressOverrideEnabled
}

var effectiveHomeAddress: String {
    devOverrideActive ? devHomeAddress : homeAddress
}

var effectiveWorkAddress: String {
    devOverrideActive ? devWorkAddress : workAddress
}

var effectiveHomeCoordinate: Coordinate? {
    devOverrideActive ? devHomeCoordinate : homeCoordinate
}

var effectiveWorkCoordinate: Coordinate? {
    devOverrideActive ? devWorkCoordinate : workCoordinate
}
```

Update `isConfigured` to use effective coordinates:

```swift
var isConfigured: Bool {
    effectiveHomeCoordinate != nil && effectiveWorkCoordinate != nil
}
```

- [ ] **Step 4: Build and verify no compile errors**

Run: `cd /Users/kevinguebert/Documents/Development/traffic-menubar && xcodebuild -scheme TrafficMenubar -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TrafficMenubar/Utilities/SettingsStore.swift
git commit -m "feat: add dev address override properties to SettingsStore"
```

---

### Task 2: Update consumers to use effective coordinates

**Files:**
- Modify: `TrafficMenubar/ViewModels/CommuteViewModel.swift`
- Modify: `TrafficMenubar/Views/PreferencesView.swift`

- [ ] **Step 1: Update CommuteViewModel.fetchRoute() to use effective coordinates**

In `CommuteViewModel.swift`, update `fetchRoute()` (line ~148) — change every reference from `settings.homeCoordinate` and `settings.workCoordinate` to `settings.effectiveHomeCoordinate` and `settings.effectiveWorkCoordinate`:

```swift
private func fetchRoute() async {
    guard settings.isConfigured,
          let home = settings.effectiveHomeCoordinate,
          let work = settings.effectiveWorkCoordinate else {
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

- [ ] **Step 2: Update CommuteViewModel.originCoordinate and destinationCoordinate**

Update the computed properties (lines ~124-134):

```swift
var originCoordinate: Coordinate {
    let home = settings.effectiveHomeCoordinate ?? Coordinate(latitude: 0, longitude: 0)
    let work = settings.effectiveWorkCoordinate ?? Coordinate(latitude: 0, longitude: 0)
    return direction == .toWork ? home : work
}

var destinationCoordinate: Coordinate {
    let home = settings.effectiveHomeCoordinate ?? Coordinate(latitude: 0, longitude: 0)
    let work = settings.effectiveWorkCoordinate ?? Coordinate(latitude: 0, longitude: 0)
    return direction == .toWork ? work : home
}
```

- [ ] **Step 3: Update PreferencesView.fetchBaseline() to use effective coordinates**

In `PreferencesView.swift`, update `fetchBaseline()` (line ~714):

```swift
private func fetchBaseline() {
    guard let home = settings.effectiveHomeCoordinate,
          let work = settings.effectiveWorkCoordinate else { return }

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

- [ ] **Step 4: Build and verify no compile errors**

Run: `cd /Users/kevinguebert/Documents/Development/traffic-menubar && xcodebuild -scheme TrafficMenubar -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TrafficMenubar/ViewModels/CommuteViewModel.swift TrafficMenubar/Views/PreferencesView.swift
git commit -m "feat: switch consumers to effective coordinates for dev override support"
```

---

### Task 3: Add Address Overrides section to DeveloperSettingsView

**Files:**
- Modify: `TrafficMenubar/Views/DeveloperSettingsView.swift`

- [ ] **Step 1: Add state variables for geocoding**

Add these `@State` properties after the existing `@State` declarations (after line ~11):

```swift
@State private var isGeocodingDevHome = false
@State private var isGeocodingDevWork = false
@State private var devHomeGeocodingError: String?
@State private var devWorkGeocodingError: String?
private let geocoder = GeocodingService()
```

- [ ] **Step 2: Add the addressOverridesSection to the body**

In the `body` VStack (line ~29), add `addressOverridesSection` after `masterToggle` and before `appStateSection`:

```swift
VStack(alignment: .leading, spacing: 12) {
    masterToggle
    if viewModel.isDevMode {
        addressOverridesSection
        appStateSection
        routeDataSection
        baselineSection
        incidentsSection
        designOverridesSection
        quickPresetsSection
    }
}
```

- [ ] **Step 3: Implement the addressOverridesSection**

Add this new section before the `// MARK: - App State` comment:

```swift
// MARK: - Address Overrides

@ViewBuilder
private var addressOverridesSection: some View {
    devSection("Address Overrides") {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Use custom addresses", isOn: $viewModel.settings.devAddressOverrideEnabled)
                .font(.system(size: 12))
                .foregroundColor(primaryText)
                .tint(.orange)

            if viewModel.settings.devAddressOverrideEnabled {
                Text("Real API calls with override addresses. Polling resumes automatically.")
                    .font(.system(size: 11))
                    .foregroundColor(secondaryText)

                devAddressField(
                    label: "Home",
                    text: $viewModel.settings.devHomeAddress,
                    isGeocoding: isGeocodingDevHome,
                    error: devHomeGeocodingError,
                    isValid: viewModel.settings.devHomeCoordinate != nil,
                    onSubmit: geocodeDevHome
                )

                devAddressField(
                    label: "Work",
                    text: $viewModel.settings.devWorkAddress,
                    isGeocoding: isGeocodingDevWork,
                    error: devWorkGeocodingError,
                    isValid: viewModel.settings.devWorkCoordinate != nil,
                    onSubmit: geocodeDevWork
                )
            }
        }
    }
}

@ViewBuilder
private func devAddressField(
    label: String,
    text: Binding<String>,
    isGeocoding: Bool,
    error: String?,
    isValid: Bool,
    onSubmit: @escaping () -> Void
) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(secondaryText)

        HStack(spacing: 8) {
            TextField("Enter address…", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .onSubmit(onSubmit)

            if isGeocoding {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else if let error = error {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                    .help(error)
            } else if isValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
            }
        }
    }
}
```

- [ ] **Step 4: Add the geocoding methods**

Add these methods before the `applyState()` method:

```swift
private func geocodeDevHome() {
    let address = viewModel.settings.devHomeAddress
    guard !address.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    isGeocodingDevHome = true
    devHomeGeocodingError = nil
    Task {
        do {
            let coord = try await geocoder.geocode(address: address)
            viewModel.settings.devHomeCoordinate = coord
            devHomeGeocodingError = nil
        } catch {
            devHomeGeocodingError = "Couldn't find this address"
            viewModel.settings.devHomeCoordinate = nil
        }
        isGeocodingDevHome = false
    }
}

private func geocodeDevWork() {
    let address = viewModel.settings.devWorkAddress
    guard !address.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    isGeocodingDevWork = true
    devWorkGeocodingError = nil
    Task {
        do {
            let coord = try await geocoder.geocode(address: address)
            viewModel.settings.devWorkCoordinate = coord
            devWorkGeocodingError = nil
        } catch {
            devWorkGeocodingError = "Couldn't find this address"
            viewModel.settings.devWorkCoordinate = nil
        }
        isGeocodingDevWork = false
    }
}
```

- [ ] **Step 5: Build and verify no compile errors**

Run: `cd /Users/kevinguebert/Documents/Development/traffic-menubar && xcodebuild -scheme TrafficMenubar -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add TrafficMenubar/Views/DeveloperSettingsView.swift
git commit -m "feat: add address overrides UI to developer settings"
```

---

### Task 4: Update master toggle subtitle when address overrides are active

**Files:**
- Modify: `TrafficMenubar/Views/DeveloperSettingsView.swift`

- [ ] **Step 1: Update the master toggle subtitle text**

In `masterToggle` (around line ~71), change the static subtitle to reflect override state:

Replace:
```swift
if viewModel.isDevMode {
    Text("Polling paused · Mock data in use")
        .font(.system(size: 11, design: .rounded))
        .foregroundColor(secondaryText)
}
```

With:
```swift
if viewModel.isDevMode {
    Text(viewModel.settings.devAddressOverrideEnabled
        ? "Custom addresses · Real API calls"
        : "Polling paused · Mock data in use")
        .font(.system(size: 11, design: .rounded))
        .foregroundColor(secondaryText)
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/kevinguebert/Documents/Development/traffic-menubar && xcodebuild -scheme TrafficMenubar -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Views/DeveloperSettingsView.swift
git commit -m "feat: update dev mode subtitle when address overrides active"
```
