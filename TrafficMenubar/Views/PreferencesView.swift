import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.openDevWindow) private var openDevWindow
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
            settings.launchAtLogin = !enabled
        }
    }
}
