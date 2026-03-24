import SwiftUI

struct QuickSettingsView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Settings")
                .font(.headline)

            Divider()

            Button(action: {
                let newDirection: CommuteDirection = viewModel.direction == .toWork ? .toHome : .toWork
                viewModel.setDirectionOverride(newDirection)
                dismiss()
            }) {
                Label(
                    viewModel.direction == .toWork ? "Switch to Home" : "Switch to Work",
                    systemImage: "arrow.triangle.swap"
                )
            }
            .buttonStyle(.plain)

            if viewModel.directionOverride != nil {
                Button(action: {
                    viewModel.setDirectionOverride(nil)
                    dismiss()
                }) {
                    Label("Auto-detect direction", systemImage: "location")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Divider()

            Button(action: {
                viewModel.refreshNow()
                dismiss()
            }) {
                Label("Refresh Now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: {
                NotificationCenter.default.post(name: .openPreferences, object: nil)
                dismiss()
            }) {
                Label("Preferences...", systemImage: "gearshape.2")
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit Traffic Menubar", systemImage: "xmark.circle")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 200)
    }
}

extension Notification.Name {
    static let openPreferences = Notification.Name("openPreferences")
}
