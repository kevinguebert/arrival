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
    @State private var showingBYOKInput = false
    @State private var byokKeyInput = ""
    @State private var isFetchingBaseline = false
    @State private var baselineFetchError: String?

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
        .frame(minWidth: 420, maxWidth: 420, minHeight: 420, maxHeight: 520)
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
                    pollingOptionButton(option: option, selection: selection)
                }
            }
        }
    }

    @ViewBuilder
    private func pollingOptionButton(
        option: (label: String, value: TimeInterval),
        selection: Binding<TimeInterval>
    ) -> some View {
        let isSelected = selection.wrappedValue == option.value
        let textColor: Color = isSelected
            ? TrafficMood.clear.darkAccentColor
            : (isDark ? .white.opacity(0.4) : .secondary)
        let bgColor: Color = isSelected
            ? TrafficMood.clear.darkAccentColor.opacity(0.15)
            : (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
        let borderColor: Color = isSelected
            ? TrafficMood.clear.darkAccentColor.opacity(0.3)
            : (isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))

        Button(action: { selection.wrappedValue = option.value }) {
            Text(option.label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(textColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
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

            // Traffic Provider
            VStack(alignment: .leading, spacing: 8) {
                Text("TRAFFIC PROVIDER")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.5) : .secondary)
                    .tracking(0.5)

                trafficProviderContent
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

    // MARK: - Traffic Provider

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
                    if settings.isConfigured {
                        fetchBaseline()
                    }
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
                    settings.clearBaselines()
                    if settings.isConfigured {
                        fetchBaseline()
                    }
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

    // MARK: - Baseline

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
        settings.clearBaselines()
        isGeocodingHome = true
        homeGeocodingError = nil
        Task {
            do {
                let coord = try await geocoder.geocode(address: settings.homeAddress)
                settings.homeCoordinate = coord
                homeGeocodingError = nil
                if settings.isConfigured {
                    fetchBaseline()
                }
            } catch {
                homeGeocodingError = "Couldn't find this address"
                settings.homeCoordinate = nil
            }
            isGeocodingHome = false
        }
    }

    private func geocodeWork() {
        settings.clearBaselines()
        isGeocodingWork = true
        workGeocodingError = nil
        Task {
            do {
                let coord = try await geocoder.geocode(address: settings.workAddress)
                settings.workCoordinate = coord
                workGeocodingError = nil
                if settings.isConfigured {
                    fetchBaseline()
                }
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
