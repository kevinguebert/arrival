import SwiftUI

@main
struct TrafficMenubarApp: App {
    @StateObject private var viewModel = CommuteViewModel()
    @Environment(\.openWindow) private var openWindow
    @State private var hasCheckedFirstLaunch = false

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
                .environment(\.openPreferencesWindow, OpenPreferencesAction { [self] in
                    openWindow(id: "preferences")
                    NSApp.activate(ignoringOtherApps: true)
                })
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
        }
        .defaultSize(width: 420, height: 320)
        .windowResizability(.contentSize)
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
