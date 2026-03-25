import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @State private var showQuickSettings = false
    @State private var moodPhrase: String = ""
    @State private var expandedRoute: Route?
    @State private var showMap = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.devDesignOverrides) private var designOverrides

    private var fontScale: CGFloat { designOverrides?.fontScale ?? 1.0 }

    private var mood: TrafficMood {
        if let override = designOverrides?.moodOverride {
            return override
        }
        return viewModel.mood
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent stripe
            LinearGradient(
                colors: [mood.darkAccentColor, mood.accentGradientEnd],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
            .animation(.easeInOut(duration: 0.4), value: mood)

            ZStack(alignment: .topTrailing) {
                // Atmospheric glow
                atmosphericGlow

                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    moodBadge

                    if let result = viewModel.currentResult {
                        if result.shouldCollapse {
                            singleRouteView(result: result)
                        } else {
                            RouteListView(result: result, originCoordinate: originCoordinate, destinationCoordinate: destinationCoordinate, selectedRoute: showMap ? expandedRoute : nil) { route in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if showMap && expandedRoute?.id == route.id {
                                        // Same route tapped while map open → close
                                        showMap = false
                                        expandedRoute = nil
                                    } else {
                                        // New route or map closed → open/swap
                                        expandedRoute = route
                                        showMap = true
                                        if let idx = result.routes.firstIndex(where: { $0.id == route.id }) {
                                            viewModel.selectedRouteIndex = idx
                                        }
                                    }
                                }
                            }
                        }

                        if showMap {
                            let selectedIndex = expandedRoute.flatMap { exp in
                                result.routes.firstIndex(where: { $0.id == exp.id })
                            } ?? 0

                            ExpandableMapView(
                                routes: result.routes,
                                selectedRoute: expandedRoute,
                                primaryRouteIndex: selectedIndex,
                                originCoordinate: originCoordinate,
                                destinationCoordinate: destinationCoordinate,
                                isExpanded: $showMap
                            )
                        }
                    }

                    footerSection
                }
                .padding(Design.popoverPadding)
            }
        }
        .background(backgroundGradient)
        .frame(width: Design.popoverWidth)
        .animation(.easeInOut(duration: 0.5), value: viewModel.fastestRoute?.travelTimeMinutes)
        .onAppear { updatePhrase() }
        .onChange(of: mood) { _ in updatePhrase() }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Design.darkBgTop, Design.darkBgBottom]
                : [Design.lightBgTop, Design.lightBgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var atmosphericGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [mood.darkAccentColor.opacity(colorScheme == .dark ? 0.10 : 0.06), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: colorScheme == .dark ? 80 : 60
                )
            )
            .frame(width: 160, height: 160)
            .offset(x: 40, y: -40)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.6), value: mood)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                directionLabel

                if viewModel.isLoading && viewModel.currentResult == nil {
                    loadingState
                } else if viewModel.hasError && viewModel.currentResult == nil {
                    errorState
                } else if let route = viewModel.fastestRoute {
                    heroTime(minutes: route.travelTimeMinutes)
                } else {
                    emptyState
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("ARRIVE BY")
                    .font(Design.labelFont(scale: fontScale))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                    .tracking(1.2)

                if let route = viewModel.fastestRoute {
                    Text(route.eta, style: .time)
                        .font(Design.etaValueFont(scale: fontScale))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .primary)
                } else {
                    Text("—:——")
                        .font(Design.etaValueFont(scale: fontScale))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.25) : .secondary.opacity(0.5))
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
                .foregroundColor(mood.darkAccentColor)

            Text(viewModel.direction == .toWork ? "TO WORK" : "TO HOME")
                .font(Design.labelFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                .tracking(1.2)
        }
    }

    @ViewBuilder
    private func heroTime(minutes: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(minutes)")
                .font(Design.heroTimeFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white : Design.darkText)
                .contentTransition(.numericText())

            Text("min")
                .font(Design.heroUnitFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
        }
    }

    // MARK: - Mood Badge

    @ViewBuilder
    private var moodBadge: some View {
        if viewModel.currentResult != nil {
            HStack(spacing: 8) {
                PulseDotView(mood: mood, size: 10)

                Text(moodPhrase)
                    .font(Design.moodFont(scale: fontScale))
                    .foregroundColor(colorScheme == .dark ? mood.darkAccentColor : mood.lightTextColor)

                if let route = viewModel.fastestRoute, baselineDelayMinutes(for: route) > 0 {
                    Text("· +\(baselineDelayMinutes(for: route)) min")
                        .font(Design.moodFont(scale: fontScale))
                        .foregroundColor(colorScheme == .dark ? mood.darkAccentColor : mood.lightTextColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(mood.darkAccentColor.opacity(0.08))
            .overlay(
                Capsule()
                    .strokeBorder(mood.darkAccentColor.opacity(0.15), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }

    private func baselineDelayMinutes(for route: Route) -> Int {
        let baseline: TimeInterval
        switch viewModel.settings.baselineCompareMode {
        case .typical:
            baseline = route.normalTravelTime
        case .bestCase:
            let persisted = viewModel.direction == .toWork
                ? viewModel.settings.baselineToWorkTime
                : viewModel.settings.baselineToHomeTime
            baseline = persisted ?? route.normalTravelTime
        }
        return max(0, Int((route.travelTime - baseline) / 60))
    }

    // MARK: - Single Route (Smart Collapse)

    @ViewBuilder
    private func singleRouteView(result: RouteResult) -> some View {
        if let route = result.fastestRoute {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if showMap {
                        showMap = false
                        expandedRoute = nil
                    } else {
                        expandedRoute = route
                        showMap = true
                    }
                }
            }) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(route.name)
                                .font(Design.routeNameFont(scale: fontScale, isFastest: true))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.7))

                            Spacer()

                            Text("\(route.travelTimeMinutes) min")
                                .font(Design.routeTimeFont(scale: fontScale, isFastest: true))
                                .foregroundColor(colorScheme == .dark ? TrafficMood.clear.darkAccentColor : TrafficMood.clear.lightTextColor)

                            Button(action: {
                                MapsURLBuilder.open(
                                    route: route,
                                    from: originCoordinate,
                                    to: destinationCoordinate,
                                    app: viewModel.settings.preferredMapsApp
                                )
                            }) {
                                Image(systemName: "arrow.triangle.turn.up.right.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .help("Open in \(viewModel.settings.preferredMapsApp.displayName)")
                        }

                        StylizedRouteLineView(
                            route: route,
                            fastestTravelTime: route.travelTime,
                            isFastest: true
                        )
                        .frame(height: 20)
                        .padding(.top, 8)
                    }
                    .padding(14)

                    Divider().opacity(colorScheme == .dark ? 0.06 : 0.08)

                    Text("Tap to see on map")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: Design.routeCardCornerRadius)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Design.routeCardCornerRadius)
                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Design.routeCardCornerRadius))
            }
            .buttonStyle(.plain)
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
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.7))
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

            if viewModel.currentResult != nil {
                Button(action: openInMaps) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle")
                        .font(.system(size: 14))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help("Open in \(viewModel.settings.preferredMapsApp.displayName)")
            }

            Spacer()

            Button(action: { showQuickSettings.toggle() }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .popover(isPresented: $showQuickSettings) {
                QuickSettingsView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Empty / Loading / Error

    @ViewBuilder
    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: EmptyState.loading.icon)
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                Text(mood.randomPhrase())
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
            }
        }
    }

    @ViewBuilder
    private var errorState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: EmptyState.error.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                Text(EmptyState.errorPhrases.randomElement() ?? EmptyState.error.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
            Text("Will retry automatically")
                .font(Design.captionFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: EmptyState.noRoute.icon)
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                Text(EmptyState.noRoute.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
            Text(EmptyState.noRoute.subtitle)
                .font(Design.captionFont(scale: fontScale))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
        }
    }

    // MARK: - Helpers

    private var originCoordinate: Coordinate { viewModel.originCoordinate }
    private var destinationCoordinate: Coordinate { viewModel.destinationCoordinate }

    private func updatePhrase() {
        moodPhrase = mood.randomPhrase()
    }

    private func openInMaps() {
        let origin = originCoordinate
        let destination = destinationCoordinate
        guard origin.latitude != 0, destination.latitude != 0 else { return }

        if let route = expandedRoute ?? viewModel.fastestRoute {
            MapsURLBuilder.open(route: route, from: origin, to: destination, app: viewModel.settings.preferredMapsApp)
        } else {
            // No route data — fall back to simple origin→destination
            let urlString = "maps://?saddr=\(origin.latitude),\(origin.longitude)&daddr=\(destination.latitude),\(destination.longitude)&dirflg=d"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
