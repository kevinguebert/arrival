import SwiftUI
import MapKit

struct DetachedMapView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @State private var recenterTrigger = UUID()
    @Environment(\.colorScheme) private var colorScheme

    private var routes: [Route] {
        viewModel.currentResult?.routes ?? []
    }

    private var selectedRoute: Route? {
        routes.indices.contains(viewModel.selectedRouteIndex) ? routes[viewModel.selectedRouteIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            mapContent
        }
        .background(colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : .white)
        .onChange(of: viewModel.currentResult?.routes.count) { _ in
            if viewModel.selectedRouteIndex >= routes.count {
                viewModel.selectedRouteIndex = 0
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 12) {
            if let route = selectedRoute {
                VStack(alignment: .leading, spacing: 2) {
                    Text(route.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("\(route.travelTimeMinutes) min")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(viewModel.mood.darkAccentColor)

                        Text("·")
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("ETA \(route.eta, style: .time)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No route data")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if routes.count > 1 {
                routePicker
            }

            Button(action: { recenterTrigger = UUID() }) {
                Image(systemName: "location.viewfinder")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Recenter map")

            Button(action: openInMaps) {
                Image(systemName: "arrow.triangle.turn.up.right.circle")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Open in \(viewModel.settings.preferredMapsApp.displayName)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            (colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : .white)
                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        )
    }

    // MARK: - Route Picker

    @ViewBuilder
    private var routePicker: some View {
        HStack(spacing: 4) {
            ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                Button(action: { viewModel.selectedRouteIndex = index }) {
                    Text(routeLabel(index: index))
                        .font(.system(size: 10, weight: viewModel.selectedRouteIndex == index ? .bold : .medium, design: .rounded))
                        .foregroundColor(viewModel.selectedRouteIndex == index ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedRouteIndex == index
                                      ? viewModel.mood.darkAccentColor
                                      : Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help(route.name)
            }
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapContent: some View {
        if !routes.isEmpty {
            MapPreviewView(
                routes: routes,
                primaryRouteIndex: viewModel.selectedRouteIndex,
                originCoordinate: viewModel.originCoordinate,
                destinationCoordinate: viewModel.destinationCoordinate,
                isInteractive: true,
                recenterTrigger: recenterTrigger
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("Waiting for route data...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Helpers

    private func routeLabel(index: Int) -> String {
        if index == 0 { return "Fastest" }
        let route = routes[index]
        let delta = route.travelTimeMinutes - (routes.first?.travelTimeMinutes ?? 0)
        return delta > 0 ? "+\(delta)m" : "Alt"
    }

    private func openInMaps() {
        guard let route = selectedRoute else { return }
        MapsURLBuilder.open(
            route: route,
            from: viewModel.originCoordinate,
            to: viewModel.destinationCoordinate,
            app: viewModel.settings.preferredMapsApp
        )
    }
}
