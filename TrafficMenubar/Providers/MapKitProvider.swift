import Foundation
import MapKit

final class MapKitProvider: TrafficProvider {
    func fetchRoute(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
        ))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        ))
        request.transportType = .automobile
        request.departureDate = Date()

        let directions = MKDirections(request: request)

        let response: MKDirections.Response
        do {
            response = try await directions.calculate()
        } catch {
            throw TrafficProviderError.networkError(error)
        }

        guard let route = response.routes.first else {
            throw TrafficProviderError.noRouteFound
        }

        let travelTime = route.expectedTravelTime
        let normalTravelTime = estimateNormalTravelTime(distanceMeters: route.distance)

        let polyline = extractPolyline(from: route.polyline)

        return RouteResult(
            travelTime: travelTime,
            normalTravelTime: normalTravelTime,
            eta: Date().addingTimeInterval(travelTime),
            incidents: [],
            routePolyline: polyline
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
