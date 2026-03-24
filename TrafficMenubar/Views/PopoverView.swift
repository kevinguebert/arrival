import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @State private var showQuickSettings = false
    @State private var refreshPulse = false
    @Environment(\.devDesignOverrides) private var designOverrides

    private var fontScale: CGFloat {
        designOverrides?.fontScale ?? 1.0
    }

    private var mood: TrafficMood {
        if let override = designOverrides?.moodOverride {
            return override
        }
        guard let route = viewModel.currentRoute else { return .unknown }
        return TrafficMood(delayMinutes: route.delayMinutes, hasIncidents: route.hasIncidents)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top mood bar — thin accent stripe
            mood.accentColor
                .frame(height: 3)
                .animation(.easeInOut(duration: 0.6), value: mood.accentColor)

            VStack(alignment: .leading, spacing: 16) {
                headerSection
                moodBadge

                if let route = viewModel.currentRoute, route.hasIncidents {
                    IncidentBannerView(
                        incidents: route.incidents,
                        delayMinutes: route.delayMinutes
                    )
                }

                mapSection
                footerSection
            }
            .padding(Design.popoverPadding)
        }
        .background(mood.backgroundTint)
        .frame(width: Design.popoverWidth)
        .animation(.easeInOut(duration: 0.5), value: viewModel.currentRoute?.travelTimeMinutes)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top) {
            // Direction + hero time
            VStack(alignment: .leading, spacing: 4) {
                directionLabel

                if viewModel.isLoading && viewModel.currentRoute == nil {
                    loadingState
                } else if viewModel.hasError && viewModel.currentRoute == nil {
                    errorState
                } else if let route = viewModel.currentRoute {
                    heroTime(minutes: route.travelTimeMinutes)
                } else {
                    emptyState
                }
            }

            Spacer()

            // ETA column
            VStack(alignment: .trailing, spacing: 4) {
                Text("ARRIVE BY")
                    .font(Design.labelFont(scale: fontScale))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                if let route = viewModel.currentRoute {
                    Text(route.eta, style: .time)
                        .font(Design.etaValueFont(scale: fontScale))
                        .foregroundColor(.primary)
                } else {
                    Text("—:——")
                        .font(Design.etaValueFont(scale: fontScale))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var directionLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: viewModel.direction == .toWork ? "building.2" : "house")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(mood.accentColor)

            Text(viewModel.direction.displayName.uppercased())
                .font(Design.labelFont(scale: fontScale))
                .foregroundColor(.secondary)
                .tracking(1.0)
        }
    }

    @ViewBuilder
    private func heroTime(minutes: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(minutes)")
                .font(Design.heroTimeFont(scale: fontScale))
                .foregroundColor(.primary)

            Text("min")
                .font(Design.heroUnitFont(scale: fontScale))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Mood Badge

    @ViewBuilder
    private var moodBadge: some View {
        if viewModel.currentRoute != nil {
            HStack(spacing: 6) {
                Text(mood.moodEmoji)
                    .font(.system(size: 13))

                Text(mood.moodPhrase)
                    .font(Design.moodFont(scale: fontScale))
                    .foregroundColor(.secondary)

                if let route = viewModel.currentRoute, route.delayMinutes > 0 {
                    Text("· +\(route.delayMinutes) min")
                        .font(Design.moodFont(scale: fontScale))
                        .foregroundColor(mood.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(mood.accentColor.opacity(0.08))
            .clipShape(Capsule())
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapSection: some View {
        if let route = viewModel.currentRoute, !route.routePolyline.isEmpty,
           let home = viewModel.settings.homeCoordinate,
           let work = viewModel.settings.workCoordinate {
            MapPreviewView(
                routePolyline: route.routePolyline,
                originCoordinate: viewModel.direction == .toWork ? home : work,
                destinationCoordinate: viewModel.direction == .toWork ? work : home,
                incidents: route.incidents
            )
            .frame(height: Design.mapHeight)
            .clipShape(RoundedRectangle(cornerRadius: Design.smallCornerRadius))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        HStack(spacing: 6) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }

            if let updateText = viewModel.timeSinceUpdate {
                Text(updateText)
                    .font(Design.captionFont(scale: fontScale))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            if viewModel.hasError {
                HStack(spacing: 3) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 10))
                    Text("Offline")
                        .font(Design.captionFont(scale: fontScale))
                }
                .foregroundColor(.orange.opacity(0.8))
            }

            if viewModel.isDevMode {
                HStack(spacing: 3) {
                    Image(systemName: "hammer")
                        .font(.system(size: 9))
                    Text("DEV")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()

            Button(action: { showQuickSettings.toggle() }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .popover(isPresented: $showQuickSettings) {
                QuickSettingsView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Empty / Loading / Error States

    @ViewBuilder
    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: EmptyState.loading.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                Text(EmptyState.loading.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Text(EmptyState.loading.subtitle)
                .font(Design.captionFont(scale: fontScale))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }

    @ViewBuilder
    private var errorState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: EmptyState.error.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                Text(EmptyState.error.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
            Text(EmptyState.error.subtitle)
                .font(Design.captionFont(scale: fontScale))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: EmptyState.noRoute.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                Text(EmptyState.noRoute.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
            Text(EmptyState.noRoute.subtitle)
                .font(Design.captionFont(scale: fontScale))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }
}
