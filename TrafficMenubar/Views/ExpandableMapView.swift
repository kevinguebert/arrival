import SwiftUI
import MapKit

struct ExpandableMapView: View {
    let routes: [Route]
    let selectedRoute: Route?
    let primaryRouteIndex: Int
    let originCoordinate: Coordinate
    let destinationCoordinate: Coordinate
    @Binding var isExpanded: Bool
    @Environment(\.openMapWindow) private var openMapWindow

    var body: some View {
        if isExpanded, selectedRoute != nil {
            ZStack(alignment: .topTrailing) {
                MapPreviewView(
                    routes: routes,
                    primaryRouteIndex: primaryRouteIndex,
                    originCoordinate: originCoordinate,
                    destinationCoordinate: destinationCoordinate
                )
                .frame(height: Design.mapHeight)
                .clipShape(RoundedRectangle(cornerRadius: Design.smallCornerRadius))
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }

                Button(action: { openMapWindow() }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Open interactive map")
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
