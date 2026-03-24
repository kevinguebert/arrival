import SwiftUI
import MapKit

struct ExpandableMapView: View {
    let routes: [Route]
    let selectedRoute: Route?
    let originCoordinate: Coordinate
    let destinationCoordinate: Coordinate
    @Binding var isExpanded: Bool

    var body: some View {
        if isExpanded, let selected = selectedRoute {
            MapPreviewView(
                routes: routes,
                primaryRouteIndex: routes.firstIndex(where: { $0.id == selected.id }) ?? 0,
                originCoordinate: originCoordinate,
                destinationCoordinate: destinationCoordinate
            )
            .frame(height: Design.mapHeight)
            .clipShape(RoundedRectangle(cornerRadius: Design.smallCornerRadius))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = false
                }
            }
        }
    }
}
