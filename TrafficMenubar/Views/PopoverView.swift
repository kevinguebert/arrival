import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @State private var showQuickSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            if let route = viewModel.currentRoute, route.hasIncidents {
                IncidentBannerView(
                    incidents: route.incidents,
                    delayMinutes: route.delayMinutes
                )
            }

            if let route = viewModel.currentRoute, !route.hasIncidents, route.delayMinutes > 0 {
                Text("+\(route.delayMinutes) min vs usual")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let route = viewModel.currentRoute, !route.routePolyline.isEmpty {
                if let home = viewModel.settings.homeCoordinate,
                   let work = viewModel.settings.workCoordinate {
                    MapPreviewView(
                        routePolyline: route.routePolyline,
                        originCoordinate: viewModel.direction == .toWork ? home : work,
                        destinationCoordinate: viewModel.direction == .toWork ? work : home,
                        incidents: route.incidents
                    )
                    .frame(height: 120)
                    .cornerRadius(8)
                }
            }

            footerSection
        }
        .padding(16)
        .frame(width: 280)
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.direction.displayName.uppercased())
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                if viewModel.isLoading {
                    Text("--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                } else if let route = viewModel.currentRoute {
                    Text("\(route.travelTimeMinutes)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    + Text(" min")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.secondary)
                } else {
                    Text("--m")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("ETA")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let route = viewModel.currentRoute {
                    Text(route.eta, style: .time)
                        .font(.system(size: 20, weight: .semibold))
                } else {
                    Text("--:--")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        HStack {
            if let updateText = viewModel.timeSinceUpdate {
                Text(updateText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if viewModel.hasError {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .help("Unable to fetch traffic data")
            }

            Spacer()

            Button(action: { showQuickSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showQuickSettings) {
                QuickSettingsView(viewModel: viewModel)
            }
        }
    }
}

