import SwiftUI

@main
struct TrafficMenubarApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text("Traffic Menubar — Coming Soon")
        } label: {
            Text("--m")
        }
        .menuBarExtraStyle(.window)
    }
}
