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
        if !viewModel.settings.isConfigured {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "preferences" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }

        viewModel.startPolling()

        NotificationCenter.default.addObserver(
            forName: .openPreferences,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "preferences" }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopPolling()
    }
}
