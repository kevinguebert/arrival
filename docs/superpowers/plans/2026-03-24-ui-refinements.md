# UI Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten the visual design with reduced border radii, better menubar status icons, unified dark-themed settings/dev-settings, smarter map route switching, and an Open in Apple Maps button.

**Architecture:** Six independent UI changes touching the design system tokens, menubar suffix text, two settings views (full visual overhaul), popover route-tap logic, and a new footer button. All changes are additive/cosmetic with no model or provider changes.

**Tech Stack:** SwiftUI, MapKit, SF Symbols, AppKit (NSWorkspace for URL opening)

**Spec:** `docs/superpowers/specs/2026-03-24-ui-refinements-design.md`

---

### Task 1: Reduce Border Radii in Design System

**Files:**
- Modify: `TrafficMenubar/Views/DesignSystem.swift:139-140,176`
- Modify: `TrafficMenubar/Views/RouteListView.swift:125`
- Modify: `TrafficMenubar/Views/DeveloperSettingsView.swift:81,84,302,323`
- Modify: `TrafficMenubar/Views/QuickSettingsView.swift:107`

- [ ] **Step 1: Update central tokens in DesignSystem.swift**

Change the three numeric constants:

```swift
// DesignSystem.swift line 139-140, 176
static let cornerRadius: CGFloat = 8        // was 12
static let smallCornerRadius: CGFloat = 6   // was 8
static let routeCardCornerRadius: CGFloat = 6  // was 10
```

- [ ] **Step 2: Update incident badge radius in RouteListView.swift**

```swift
// RouteListView.swift line 125
.clipShape(RoundedRectangle(cornerRadius: 3))  // was 4
```

- [ ] **Step 3: Update DeveloperSettingsView hard-coded radii**

Master toggle (lines 81, 84):
```swift
// Change both cornerRadius: 8 to cornerRadius: 6
RoundedRectangle(cornerRadius: 6)
```

Preset buttons (line 302):
```swift
.clipShape(RoundedRectangle(cornerRadius: 4))  // was 6
```

Dev section helper (line 323):
```swift
.clipShape(RoundedRectangle(cornerRadius: 6))  // was 8
```

- [ ] **Step 4: Update QuickSettingsView button radius**

```swift
// QuickSettingsView.swift line 107
.cornerRadius(4)  // was 6
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add TrafficMenubar/Views/DesignSystem.swift TrafficMenubar/Views/RouteListView.swift TrafficMenubar/Views/DeveloperSettingsView.swift TrafficMenubar/Views/QuickSettingsView.swift
git commit -m "style: reduce border radii across design system for tighter look"
```

---

### Task 2: Update Menubar Status Icons

**Files:**
- Modify: `TrafficMenubar/Views/DesignSystem.swift:105-111`

- [ ] **Step 1: Update menuBarSuffix in TrafficMood**

```swift
// DesignSystem.swift lines 105-111
var menuBarSuffix: String {
    switch self {
    case .clear:    return " ●"
    case .moderate: return " ▲"
    case .heavy:    return " ‼"
    case .unknown:  return ""
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TrafficMenubar/Views/DesignSystem.swift
git commit -m "feat: update menubar icons to circle/triangle/exclamation progression"
```

---

### Task 3: Redesign PreferencesView with Dark Theme

**Files:**
- Modify: `TrafficMenubar/Views/PreferencesView.swift` (full overhaul)

- [ ] **Step 1: Replace the PreferencesView body and tab structure**

Replace the entire `body` computed property with the dark-themed version. The key changes:
- Dark gradient background (`Design.darkBgTop` → `Design.darkBgBottom`)
- 3px green accent stripe at the top
- Custom tab bar with green active indicator (replacing system TabView)
- All form inputs use dark styling (white 6% bg, white 10% border, 6pt radius)
- Labels are 11px uppercase semibold at white 50% opacity
- System rounded font throughout

```swift
var body: some View {
    VStack(spacing: 0) {
        // Accent stripe
        LinearGradient(
            colors: [TrafficMood.clear.darkAccentColor, TrafficMood.clear.accentGradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 3)

        // Custom tab bar
        HStack(spacing: 0) {
            tabButton("Addresses", icon: "mappin.and.ellipse", tab: .addresses)
            tabButton("Schedule", icon: "clock", tab: .schedule)
            tabButton("General", icon: "gearshape", tab: .general)
        }
        .padding(.horizontal, 20)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )

        // Tab content
        Group {
            switch selectedTab {
            case .addresses: addressesTab
            case .schedule:  scheduleTab
            case .general:   generalTab
            }
        }
        .padding(20)
    }
    .background(
        LinearGradient(
            colors: [Design.darkBgTop, Design.darkBgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    )
    .frame(width: 420, height: 360)
}
```

Add tab state and enum:
```swift
@State private var selectedTab: SettingsTab = .addresses

enum SettingsTab {
    case addresses, schedule, general
}
```

Add tab button helper:
```swift
@ViewBuilder
private func tabButton(_ label: String, icon: String, tab: SettingsTab) -> some View {
    Button(action: { selectedTab = tab }) {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
        }
        .foregroundColor(selectedTab == tab ? TrafficMood.clear.darkAccentColor : .white.opacity(0.45))
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .overlay(
            Rectangle()
                .fill(selectedTab == tab ? TrafficMood.clear.darkAccentColor : Color.clear)
                .frame(height: 2),
            alignment: .bottom
        )
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 2: Restyle the Addresses tab**

Replace the Form-based layout with dark-styled manual VStack layout:

```swift
@ViewBuilder
private var addressesTab: some View {
    VStack(alignment: .leading, spacing: 16) {
        darkTextField(
            label: "Home Address",
            text: $settings.homeAddress,
            isGeocoding: isGeocodingHome,
            error: homeGeocodingError,
            isValid: settings.homeCoordinate != nil,
            onSubmit: geocodeHome
        )

        darkTextField(
            label: "Work Address",
            text: $settings.workAddress,
            isGeocoding: isGeocodingWork,
            error: workGeocodingError,
            isValid: settings.workCoordinate != nil,
            onSubmit: geocodeWork
        )

        Divider().opacity(0.06)

        Text("Addresses are geocoded to coordinates for routing. Press Return to validate.")
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(.white.opacity(0.35))
            .lineSpacing(2)

        Spacer()
    }
}
```

Add dark text field helper:
```swift
@ViewBuilder
private func darkTextField(
    label: String,
    text: Binding<String>,
    isGeocoding: Bool,
    error: String?,
    isValid: Bool,
    onSubmit: @escaping () -> Void
) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .tracking(0.5)

        HStack(spacing: 8) {
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onSubmit(onSubmit)

            if isGeocoding {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else if let error = error {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .help(error)
            } else if isValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(TrafficMood.clear.darkAccentColor)
            }
        }
    }
}
```

- [ ] **Step 3: Restyle the Schedule tab**

Replace Form-based schedule with dark-styled layout using custom segmented-style pill buttons for polling frequency:

```swift
@ViewBuilder
private var scheduleTab: some View {
    VStack(alignment: .leading, spacing: 20) {
        // Morning commute
        VStack(alignment: .leading, spacing: 8) {
            Text("MORNING COMMUTE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            HStack(spacing: 10) {
                darkTimePicker(
                    selection: Binding(
                        get: { timeTag(hour: settings.morningStartHour, minute: settings.morningStartMinute) },
                        set: { settings.morningStartHour = $0 / 60; settings.morningStartMinute = $0 % 60 }
                    )
                )
                Text("to")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                darkTimePicker(
                    selection: Binding(
                        get: { timeTag(hour: settings.morningEndHour, minute: settings.morningEndMinute) },
                        set: { settings.morningEndHour = $0 / 60; settings.morningEndMinute = $0 % 60 }
                    )
                )
            }
        }

        // Evening commute
        VStack(alignment: .leading, spacing: 8) {
            Text("EVENING COMMUTE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            HStack(spacing: 10) {
                darkTimePicker(
                    selection: Binding(
                        get: { timeTag(hour: settings.eveningStartHour, minute: settings.eveningStartMinute) },
                        set: { settings.eveningStartHour = $0 / 60; settings.eveningStartMinute = $0 % 60 }
                    )
                )
                Text("to")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                darkTimePicker(
                    selection: Binding(
                        get: { timeTag(hour: settings.eveningEndHour, minute: settings.eveningEndMinute) },
                        set: { settings.eveningEndHour = $0 / 60; settings.eveningEndMinute = $0 % 60 }
                    )
                )
            }
        }

        Divider().opacity(0.06)

        // Polling frequency
        VStack(alignment: .leading, spacing: 12) {
            Text("POLLING FREQUENCY")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)

            pollingRow(
                label: "During commute",
                selection: $settings.commutePollingInterval,
                options: [
                    (label: "1m", value: TimeInterval(60)),
                    (label: "3m", value: TimeInterval(180)),
                    (label: "5m", value: TimeInterval(300)),
                    (label: "10m", value: TimeInterval(600)),
                ]
            )
            pollingRow(
                label: "Off-peak",
                selection: $settings.offPeakPollingInterval,
                options: [
                    (label: "5m", value: TimeInterval(300)),
                    (label: "10m", value: TimeInterval(600)),
                    (label: "15m", value: TimeInterval(900)),
                    (label: "30m", value: TimeInterval(1800)),
                ]
            )
        }

        Spacer()
    }
}
```

Add helpers for the schedule tab:

```swift
@ViewBuilder
private func darkTimePicker(selection: Binding<Int>) -> some View {
    Picker("", selection: selection) {
        ForEach(timeSlots(), id: \.hour) { slot in
            Text(slot.label).tag(timeTag(hour: slot.hour, minute: slot.minute))
        }
    }
    .labelsHidden()
    .frame(width: 80)
}

@ViewBuilder
private func pollingRow(
    label: String,
    selection: Binding<TimeInterval>,
    options: [(label: String, value: TimeInterval)]
) -> some View {
    HStack {
        Text(label)
            .font(.system(size: 13, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
        Spacer()
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                Button(action: { selection.wrappedValue = option.value }) {
                    Text(option.label)
                        .font(.system(size: 12, weight: selection.wrappedValue == option.value ? .semibold : .regular, design: .rounded))
                        .foregroundColor(selection.wrappedValue == option.value
                            ? TrafficMood.clear.darkAccentColor
                            : .white.opacity(0.4))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selection.wrappedValue == option.value
                            ? TrafficMood.clear.darkAccentColor.opacity(0.15)
                            : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(selection.wrappedValue == option.value
                                    ? TrafficMood.clear.darkAccentColor.opacity(0.3)
                                    : Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 4: Restyle the General tab**

Replace Form-based layout with dark-styled manual layout:

```swift
@ViewBuilder
private var generalTab: some View {
    VStack(alignment: .leading, spacing: 16) {
        // Startup
        VStack(alignment: .leading, spacing: 8) {
            Text("STARTUP")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            Toggle("Launch at login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { newValue in
                    settings.launchAtLogin = newValue
                    updateLaunchAtLogin(newValue)
                }
            ))
            .font(.system(size: 13, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .tint(TrafficMood.clear.darkAccentColor)
        }

        Divider().opacity(0.06)

        // Location
        VStack(alignment: .leading, spacing: 8) {
            Text("LOCATION")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            Text("Location access enables automatic direction detection (home vs. work). Without it, direction is based on time of day.")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .lineSpacing(2)
        }

        Divider().opacity(0.06)

        // Traffic Provider
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAFFIC PROVIDER")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            HStack {
                Text("Apple Maps")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("More coming soon")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.25))
            }
        }

        Divider().opacity(0.06)

        // Developer
        VStack(alignment: .leading, spacing: 8) {
            Text("DEVELOPER")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            Toggle("Developer Mode", isOn: $settings.developerModeEnabled)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .tint(.orange)
            if settings.developerModeEnabled {
                Button("Open Developer Settings") {
                    openDevWindow()
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.orange)
            }
            Text("Enables mock data controls for testing UI states.")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.white.opacity(0.25))
        }

        Spacer()
    }
}
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add TrafficMenubar/Views/PreferencesView.swift
git commit -m "feat: redesign settings modal with dark theme matching popover"
```

---

### Task 4: Redesign DeveloperSettingsView with Dark Theme

**Files:**
- Modify: `TrafficMenubar/Views/DeveloperSettingsView.swift` (visual overhaul)

- [ ] **Step 1: Add dark gradient background to the ScrollView body**

Wrap the existing content in a dark background. Change the `body`:

```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            masterToggle
            if viewModel.isDevMode {
                appStateSection
                routeDataSection
                incidentsSection
                designOverridesSection
                quickPresetsSection
            }
        }
        .padding(16)
    }
    .background(
        LinearGradient(
            colors: [Design.darkBgTop, Design.darkBgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    )
    .frame(width: 400)
    .frame(minHeight: 500)
    .onChange(of: forcedState) { _ in applyState() }
    .onChange(of: forcedDirection) { _ in applyState() }
    .onChange(of: forcedFailures) { _ in applyState() }
    .onChange(of: mockProvider.travelTimeMinutes) { _ in applyState() }
    .onChange(of: mockProvider.normalTimeMinutes) { _ in applyState() }
    .onChange(of: mockProvider.includeIncidents) { _ in applyState() }
    .onChange(of: mockProvider.incidentCount) { _ in applyState() }
    .onChange(of: mockProvider.maxSeverity) { _ in applyState() }
}
```

Note: Reduced spacing from 16 to 12 and padding from 20 to 16 for the denser utilitarian feel.

- [ ] **Step 2: Update the devSection helper for dark/orange theme**

```swift
@ViewBuilder
private func devSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.orange)
            .tracking(1.0)
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
```

- [ ] **Step 3: Update masterToggle for dark theme**

```swift
@ViewBuilder
private var masterToggle: some View {
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .foregroundColor(.orange)
                Text(viewModel.isDevMode ? "Dev Mode Active" : "Dev Mode Off")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            if viewModel.isDevMode {
                Text("Polling paused · Mock data in use")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
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
    .background(viewModel.isDevMode ? Color.orange.opacity(0.08) : Color.white.opacity(0.04))
    .overlay(
        RoundedRectangle(cornerRadius: 6)
            .stroke(viewModel.isDevMode ? Color.orange.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 6))
}
```

- [ ] **Step 4: Update text colors in all section content**

Update text styling in `appStateSection`, `routeDataSection`, `incidentsSection`, `designOverridesSection` to use white text on dark background:

All `.font(.system(size: 12))` labels should add `.foregroundColor(.white.opacity(0.7))`.

All `.foregroundColor(.secondary)` should become `.foregroundColor(.white.opacity(0.4))`.

All `.foregroundColor(.accentColor)` should become `.foregroundColor(.orange)`.

Toggle tints should use `.tint(.orange)`.

- [ ] **Step 5: Update quick presets for dark theme with orange accent**

```swift
FlowLayout(spacing: 6) {
    ForEach(presets, id: \.0) { label, action in
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

- [ ] **Step 6: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add TrafficMenubar/Views/DeveloperSettingsView.swift
git commit -m "feat: redesign developer settings with dark theme and orange accents"
```

---

### Task 5: Smart Map Route Switching

**Files:**
- Modify: `TrafficMenubar/Views/PopoverView.swift:44-53,211-215`

- [ ] **Step 1: Update RouteListView tap handler**

Replace the closure at lines 44-53:

```swift
RouteListView(result: result) { route in
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        if showMap && expandedRoute?.id == route.id {
            // Same route tapped while map open → close
            showMap = false
            expandedRoute = nil
        } else {
            // New route or map closed → open/swap
            expandedRoute = route
            showMap = true
        }
    }
}
```

- [ ] **Step 2: Update singleRouteView tap handler**

Replace the Button action at lines 211-215:

```swift
Button(action: {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        if showMap {
            showMap = false
            expandedRoute = nil
        } else {
            expandedRoute = route
            showMap = true
        }
    }
}) {
```

Note: Single route view only has one route so "swap" never applies — it's just open/close.

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/PopoverView.swift
git commit -m "feat: clicking routes swaps map highlight instead of toggling"
```

---

### Task 6: Open in Apple Maps Button

**Files:**
- Modify: `TrafficMenubar/Views/PopoverView.swift:272-323` (footer section)

- [ ] **Step 1: Add the Apple Maps button to the footer**

Insert before the `Spacer()` in `footerSection` (after the DEV badge block, before `Spacer()`):

```swift
// In footerSection, add after the dev mode badge block and before Spacer():
if viewModel.currentResult != nil {
    Button(action: openInAppleMaps) {
        Image(systemName: "arrow.triangle.turn.up.right.circle")
            .font(.system(size: 14))
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
    .help("Open in Apple Maps")
}
```

- [ ] **Step 2: Add the openInAppleMaps helper function**

Add to the Helpers MARK section (after `updatePhrase`):

```swift
private func openInAppleMaps() {
    let origin = originCoordinate
    let destination = destinationCoordinate
    guard origin.latitude != 0, destination.latitude != 0 else { return }

    let urlString = "maps://?saddr=\(origin.latitude),\(origin.longitude)&daddr=\(destination.latitude),\(destination.longitude)&dirflg=d"
    if let url = URL(string: urlString) {
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TrafficMenubar/Views/PopoverView.swift
git commit -m "feat: add Open in Apple Maps button to footer"
```
