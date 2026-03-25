import SwiftUI

struct StylizedRouteLineView: View {
    let route: Route
    let fastestTravelTime: TimeInterval
    let isFastest: Bool
    @Environment(\.colorScheme) private var colorScheme

    @State private var drawProgress: CGFloat = 0

    private var lineThickness: CGFloat { isFastest ? 3 : 2 }
    private var dotSize: CGFloat { isFastest ? 10 : 7 }
    private var overallOpacity: Double { isFastest ? 1.0 : 0.5 }

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(originColor)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: originColor.opacity(isFastest ? 0.4 : 0), radius: isFastest ? 4 : 0)
                .zIndex(2)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    let hasCongestion = route.segmentCongestion != nil && !(route.segmentCongestion?.isEmpty ?? true)

                    if isFastest {
                        Group {
                            if hasCongestion { congestionGradientLine } else { gradientLine }
                        }
                        .frame(height: lineThickness + 6)
                        .opacity(0.08)
                        .blur(radius: 2)
                    }

                    Group {
                        if hasCongestion { congestionGradientLine } else { gradientLine }
                    }
                    .frame(height: lineThickness)
                    .mask(
                        Rectangle()
                            .frame(width: geo.size.width * drawProgress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )

                    if route.hasIncidents {
                        incidentDiamond
                            .position(x: geo.size.width * 0.45, y: geo.size.height / 2)
                            .opacity(Double(drawProgress))
                    }
                }
            }
            .frame(height: dotSize)
            .padding(.horizontal, -2)

            Circle()
                .fill(destinationColor)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: destinationColor.opacity(isFastest ? 0.3 : 0), radius: isFastest ? 4 : 0)
                .zIndex(2)
        }
        .opacity(overallOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(isFastest ? 0 : 0.15)) {
                drawProgress = 1.0
            }
        }
    }

    @ViewBuilder
    private var gradientLine: some View {
        let delayRatio = fastestTravelTime > 0
            ? (route.travelTime - fastestTravelTime) / fastestTravelTime
            : 0

        if delayRatio < 0.1 {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [Color(red: 0.29, green: 0.68, blue: 0.50)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
        } else if delayRatio < 0.3 {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.29, green: 0.68, blue: 0.50), location: 0),
                        .init(color: Color(red: 0.98, green: 0.75, blue: 0.14), location: 0.4),
                        .init(color: Color(red: 0.98, green: 0.75, blue: 0.14), location: 0.6),
                        .init(color: Color(red: 0.29, green: 0.68, blue: 0.50), location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.29, green: 0.68, blue: 0.50), location: 0),
                        .init(color: Color(red: 0.98, green: 0.75, blue: 0.14), location: 0.25),
                        .init(color: Color(red: 0.97, green: 0.44, blue: 0.44), location: 0.45),
                        .init(color: Color(red: 0.97, green: 0.44, blue: 0.44), location: 0.55),
                        .init(color: Color(red: 0.98, green: 0.75, blue: 0.14), location: 0.75),
                        .init(color: Color(red: 0.29, green: 0.68, blue: 0.50), location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
        }
    }

    @ViewBuilder
    private var congestionGradientLine: some View {
        if let congestion = route.segmentCongestion, !congestion.isEmpty {
            let stops = congestion.enumerated().map { index, level in
                Gradient.Stop(
                    color: level.color,
                    location: CGFloat(index) / CGFloat(max(congestion.count - 1, 1))
                )
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    stops: stops,
                    startPoint: .leading,
                    endPoint: .trailing
                ))
        }
    }

    private var incidentDiamond: some View {
        Rectangle()
            .fill(Color(red: 0.96, green: 0.62, blue: 0.04))
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(45))
            .shadow(color: Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.5), radius: 3)
    }

    private var originColor: Color {
        isFastest
            ? Color(red: 0.29, green: 0.68, blue: 0.50)
            : (colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.15))
    }

    private var destinationColor: Color {
        isFastest
            ? Color(red: 0.97, green: 0.44, blue: 0.44)
            : (colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.15))
    }
}
