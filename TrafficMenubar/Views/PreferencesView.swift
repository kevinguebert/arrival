import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.openDevWindow) private var openDevWindow
    @Environment(\.colorScheme) private var colorScheme
    @State private var homeGeocodingError: String?
    @State private var workGeocodingError: String?
    @State private var isGeocodingHome = false
    @State private var isGeocodingWork = false
    @State private var selectedTab: SettingsTab = .addresses

    enum SettingsTab {
        case addresses, schedule, general
    }

    private let geocoder = GeocodingService()

    private var isDark: Bool { colorScheme == .dark }

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
                    .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
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
        .background(backgroundGradient)
        .frame(width: 420, height: 420)
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private func tabButton(_ label: String, icon: String, tab: SettingsTab) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
            }
            .foregroundColor(selectedTab == tab
                ? TrafficMood.clear.darkAccentColor
                : (isDark ? .white.opacity(0.45) : .secondary))
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

    // MARK: - Addresses Tab

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

            Divider().opacity(isDark ? 0.06 : 0.15)

            Text("Addresses are geocoded to coordinates for routing. Press Return to validate.")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(isDark ? .white.opacity(0.35) : .secondary)
                .lineSpacing(2)

            Spacer()
        }
    }

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
                .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
                .tracking(0.5)

            HStack(spacing: 8) {
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.7) : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
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

    // MARK: - Schedule Tab

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
        VStack(alignment: .leading, spacing: 20) {
            // Morning commute
            VStack(alignment: .leading, spacing: 8) {
                Text("MORNING COMMUTE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
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
                        .foregroundColor(isDark ? .white.opacity(0.3) : .secondary)
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
                    .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
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
                        .foregroundColor(isDark ? .white.opacity(0.3) : .secondary)
                    darkTimePicker(
                        selection: Binding(
                            get: { timeTag(hour: settings.eveningEndHour, minute: settings.eveningEndMinute) },
                            set: { settings.eveningEndHour = $0 / 60; settings.eveningEndMinute = $0 % 60 }
                        )
                    )
                }
            }

            Divider().opacity(isDark ? 0.06 : 0.15)

            // Polling frequency
            VStack(alignment: .leading, spacing: 12) {
                Text("POLLING FREQUENCY")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
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

    @ViewBuilder
    private func darkTimePicker(selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(timeSlots(), id: \.label) { slot in
                Text(slot.label).tag(timeTag(hour: slot.hour, minute: slot.minute))
            }
        }
        .labelsHidden()
        .frame(width: 80)
        .colorScheme(colorScheme)
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
                .foregroundColor(isDark ? .white.opacity(0.7) : .primary)
            Spacer()
            HStack(spacing: 4) {
                ForEach(options, id: \.value) { option in
                    Button(action: { selection.wrappedValue = option.value }) {
                        Text(option.label)
                            .font(.system(size: 12, weight: selection.wrappedValue == option.value ? .semibold : .regular, design: .rounded))
                            .foregroundColor(selection.wrappedValue == option.value
                                ? TrafficMood.clear.darkAccentColor
                                : (isDark ? .white.opacity(0.4) : .secondary))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(selection.wrappedValue == option.value
                                ? TrafficMood.clear.darkAccentColor.opacity(0.15)
                                : (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(selection.wrappedValue == option.value
                                        ? TrafficMood.clear.darkAccentColor.opacity(0.3)
                                        : (isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Startup
            VStack(alignment: .leading, spacing: 8) {
                Text("STARTUP")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
                    .tracking(0.5)
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        updateLaunchAtLogin(newValue)
                    }
                ))
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(isDark ? .white.opacity(0.7) : .primary)
                .tint(TrafficMood.clear.darkAccentColor)
            }

            Divider().opacity(isDark ? 0.06 : 0.15)

            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("LOCATION")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
                    .tracking(0.5)
                Text("Location access enables automatic direction detection (home vs. work). Without it, direction is based on time of day.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.35) : .secondary)
                    .lineSpacing(2)
            }

            Divider().opacity(isDark ? 0.06 : 0.15)

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

            Divider().opacity(isDark ? 0.06 : 0.15)

            // Developer
            VStack(alignment: .leading, spacing: 8) {
                Text("DEVELOPER")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
                    .tracking(0.5)
                Toggle("Developer Mode", isOn: $settings.developerModeEnabled)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.7) : .primary)
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
                    .foregroundColor(isDark ? .white.opacity(0.25) : .secondary.opacity(0.6))
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private var backgroundGradient: some View {
        LinearGradient(
            colors: isDark
                ? [Design.darkBgTop, Design.darkBgBottom]
                : [Design.lightBgTop, Design.lightBgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Geocoding

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
            settings.launchAtLogin = !enabled
        }
    }
}
