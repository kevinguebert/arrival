import Foundation
import MapKit

final class MapKitProvider: TrafficProvider {
    func fetchRoutes(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
        ))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        ))
        request.transportType = .automobile
        request.departureDate = Date()
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)

        let response: MKDirections.Response
        do {
            response = try await directions.calculate()
        } catch {
            throw TrafficProviderError.networkError(error)
        }

        guard !response.routes.isEmpty else {
            throw TrafficProviderError.noRouteFound
        }

        let sortedRoutes = response.routes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
        let routes = Array(sortedRoutes.prefix(3)).map { mkRoute in
            Route(
                name: mkRoute.name,
                travelTime: mkRoute.expectedTravelTime,
                normalTravelTime: estimateNormalTravelTime(distanceMeters: mkRoute.distance),
                distance: mkRoute.distance,
                polylineCoordinates: extractPolyline(from: mkRoute.polyline),
                mkPolyline: mkRoute.polyline,
                advisoryNotices: mkRoute.advisoryNotices,
                segmentCongestion: nil
            )
        }

        return RouteResult(
            routes: routes,
            incidents: [],
            fetchedAt: Date()
        )
    }

    private func estimateNormalTravelTime(distanceMeters: Double) -> TimeInterval {
        let averageSpeedMPS = 50.0 * 1000.0 / 3600.0
        return distanceMeters / averageSpeedMPS
    }

    private func extractPolyline(from polyline: MKPolyline) -> [Coordinate] {
        let pointCount = polyline.pointCount
        let points = polyline.points()
        var coordinates: [Coordinate] = []
        coordinates.reserveCapacity(pointCount)

        let stride = max(1, pointCount / 100)
        for i in Swift.stride(from: 0, to: pointCount, by: stride) {
            let mapPoint = points[i]
            let coord = mapPoint.coordinate
            coordinates.append(Coordinate(latitude: coord.latitude, longitude: coord.longitude))
        }

        if let lastIndex = (0..<pointCount).last, coordinates.last != Coordinate(latitude: points[lastIndex].coordinate.latitude, longitude: points[lastIndex].coordinate.longitude) {
            let coord = points[lastIndex].coordinate
            coordinates.append(Coordinate(latitude: coord.latitude, longitude: coord.longitude))
        }

        return coordinates
    }
}
