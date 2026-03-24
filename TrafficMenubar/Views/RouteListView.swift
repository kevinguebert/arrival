import SwiftUI

struct RouteListView: View {
    let result: RouteResult
    let onRouteTap: (Route) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.devDesignOverrides) private var designOverrides

    private var fontScale: CGFloat { designOverrides?.fontScale ?? 1.0 }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(result.routes.enumerated()), id: \.element.id) { index, route in
                let isFastest = index == 0

                routeRow(route: route, isFastest: isFastest)

                if index < result.routes.count - 1 {
                    Divider()
                        .opacity(colorScheme == .dark ? 0.06 : 0.08)
                }
            }

            Divider().opacity(colorScheme == .dark ? 0.06 : 0.08)
            Text("Tap route to see on map")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: Design.routeCardCornerRadius)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.02)
                    : Color.black.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.routeCardCornerRadius)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.06)
                        : Color.black.opacity(0.05),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Design.routeCardCornerRadius))
    }

    @ViewBuilder
    private func routeRow(route: Route, isFastest: Bool) -> some View {
        let fastestTime = result.fastestRoute?.travelTime ?? route.travelTime
        let delta = route.travelTimeMinutes - (result.fastestRoute?.travelTimeMinutes ?? 0)

        Button(action: { onRouteTap(route) }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 5) {
                        Text(route.name)
                            .font(Design.routeNameFont(scale: fontScale, isFastest: isFastest))
                            .foregroundColor(isFastest
                                ? (colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.7))
                                : (colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)))

                        if route.hasIncidents {
                            incidentBadge
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(route.travelTimeMinutes) min")
                            .font(Design.routeTimeFont(scale: fontScale, isFastest: isFastest))
                            .foregroundColor(isFastest
                                ? (colorScheme == .dark ? TrafficMood.clear.darkAccentColor : TrafficMood.clear.lightTextColor)
                                : (colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.3)))

                        if !isFastest && delta > 0 {
                            Text("+\(delta)")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                        }
                    }
                }

                if route.hasIncidents, let notice = route.advisoryNotices.first {
                    Text(notice)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.25) : .black.opacity(0.2))
                        .lineLimit(1)
                        .padding(.top, 2)
                }

                StylizedRouteLineView(
                    route: route,
                    fastestTravelTime: fastestTime,
                    isFastest: isFastest
                )
                .frame(height: isFastest ? 20 : 16)
                .padding(.top, 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isFastest
                ? TrafficMood.clear.darkAccentColor.opacity(0.04)
                : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var incidentBadge: some View {
        HStack(spacing: 3) {
            Rectangle()
                .fill(Color(red: 0.96, green: 0.62, blue: 0.04))
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))

            Text("INCIDENT")
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
