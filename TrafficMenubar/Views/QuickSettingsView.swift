import SwiftUI

struct QuickSettingsView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openPreferencesWindow) private var openPreferencesWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text("Quick Settings")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.bottom, 4)

            Divider().opacity(0.5)

            // Direction toggle
            settingsButton(
                icon: "arrow.triangle.swap",
                label: viewModel.direction == .toWork ? "Switch to Home" : "Switch to Work",
                tint: .blue
            ) {
                let newDirection: CommuteDirection = viewModel.direction == .toWork ? .toHome : .toWork
                viewModel.setDirectionOverride(newDirection)
                dismiss()
            }

            // Auto-detect (only shown when override is active)
            if viewModel.directionOverride != nil {
                settingsButton(
                    icon: "location",
                    label: "Auto-detect direction",
                    tint: .green,
                    subtle: true
                ) {
                    viewModel.setDirectionOverride(nil)
                    dismiss()
                }
            }

            Divider().opacity(0.5)

            // Refresh
            settingsButton(
                icon: "arrow.clockwise",
                label: "Refresh Now",
                tint: .blue
            ) {
                viewModel.refreshNow()
                dismiss()
            }

            Divider().opacity(0.5)

            // Preferences
            settingsButton(
                icon: "gearshape.2",
                label: "Preferences...",
                tint: .secondary
            ) {
                openPreferencesWindow()
                dismiss()
            }

            Divider().opacity(0.5)

            // Quit
            settingsButton(
                icon: "xmark.circle",
                label: "Quit Traffic Menubar",
                tint: .secondary,
                subtle: true
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 220)
    }

    @ViewBuilder
    private func settingsButton(
        icon: String,
        label: String,
        tint: Color,
        subtle: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(tint)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13, weight: subtle ? .regular : .medium, design: .rounded))
                    .foregroundColor(subtle ? .secondary : .primary)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cornerRadius(4)
    }
}

extension Notification.Name {
    static let openPreferences = Notification.Name("openPreferences")
}
