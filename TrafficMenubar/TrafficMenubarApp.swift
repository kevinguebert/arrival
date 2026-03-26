import SwiftUI
import Sparkle

@main
struct TrafficMenubarApp: App {
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    @StateObject private var viewModel = CommuteViewModel()
    @Environment(\.openWindow) private var openWindow
    @State private var hasCheckedFirstLaunch = false
    @StateObject private var mockProvider = MockTrafficProvider()
    @StateObject private var designOverrides = DevDesignOverrides()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
                .environment(\.openPreferencesWindow, OpenPreferencesAction { [self] in
                    openWindow(id: "preferences")
                    NSApp.activate(ignoringOtherApps: true)
                })
                .environment(\.openMapWindow, OpenMapWindowAction { [self] in
                    openWindow(id: "traffic-map")
                    NSApp.activate(ignoringOtherApps: true)
                })
                .environment(\.devDesignOverrides, designOverrides)
                .environmentObject(designOverrides)
                .onAppear {
                    if !hasCheckedFirstLaunch {
                        hasCheckedFirstLaunch = true
                        viewModel.startPolling()

                        if !viewModel.settings.isConfigured {
                            openWindow(id: "preferences")
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                }
        } label: {
            Text(viewModel.menuBarText)
        }
        .menuBarExtraStyle(.window)

        Window("Preferences", id: "preferences") {
            PreferencesView(settings: viewModel.settings)
                .environment(\.openDevWindow, OpenDevWindowAction { [self] in
                    openWindow(id: "developer")
                    NSApp.activate(ignoringOtherApps: true)
                })
        }
        .defaultSize(width: 420, height: 520)
        .windowResizability(.contentSize)

        Window("Traffic Map", id: "traffic-map") {
            DetachedMapView(viewModel: viewModel)
        }
        .defaultSize(width: Design.detachedMapWidth, height: Design.detachedMapHeight)
        .windowResizability(.contentMinSize)

        Window("Developer Settings", id: "developer") {
            DeveloperSettingsView(
                viewModel: viewModel,
                mockProvider: mockProvider,
                designOverrides: designOverrides
            )
        }
        .defaultSize(width: 400, height: 600)
        .windowResizability(.contentMinSize)
    }
}

// Environment key for passing openPreferences action down the view hierarchy
struct OpenPreferencesAction {
    let action: () -> Void
    func callAsFunction() { action() }
}

struct OpenPreferencesKey: EnvironmentKey {
    static let defaultValue = OpenPreferencesAction { }
}

extension EnvironmentValues {
    var openPreferencesWindow: OpenPreferencesAction {
        get { self[OpenPreferencesKey.self] }
        set { self[OpenPreferencesKey.self] = newValue }
    }
}

struct OpenMapWindowAction {
    let action: () -> Void
    func callAsFunction() { action() }
}

struct OpenMapWindowKey: EnvironmentKey {
    static let defaultValue = OpenMapWindowAction { }
}

extension EnvironmentValues {
    var openMapWindow: OpenMapWindowAction {
        get { self[OpenMapWindowKey.self] }
        set { self[OpenMapWindowKey.self] = newValue }
    }
}

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
