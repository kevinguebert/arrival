import Foundation
import AppKit

enum MapsURLBuilder {
    static func open(route: Route, from origin: Coordinate, to destination: Coordinate, app: MapsApp) {
        guard let url = url(for: route, from: origin, to: destination, app: app) else { return }
        NSWorkspace.shared.open(url)
    }

    static func url(for route: Route, from origin: Coordinate, to destination: Coordinate, app: MapsApp) -> URL? {
        switch app {
        case .googleMaps:
            return googleMapsURL(route: route, origin: origin, destination: destination)
        case .appleMaps:
            return appleMapsURL(origin: origin, destination: destination)
        }
    }

    // MARK: - Google Maps (supports waypoints for route-specific directions)

    private static func googleMapsURL(route: Route, origin: Coordinate, destination: Coordinate) -> URL? {
        let originStr = coord(origin)
        let destStr = coord(destination)
        let waypoints = strategicWaypoints(from: route.polylineCoordinates)

        var urlString = "https://www.google.com/maps/dir/?api=1"
        urlString += "&origin=\(originStr)"
        urlString += "&destination=\(destStr)"
        urlString += "&travelmode=driving"

        if !waypoints.isEmpty {
            let waypointStr = waypoints.map { coord($0) }.joined(separator: "|")
            urlString += "&waypoints=\(waypointStr)"
        }

        return URL(string: urlString)
    }

    // MARK: - Apple Maps (no waypoint support — opens origin→destination)

    private static func appleMapsURL(origin: Coordinate, destination: Coordinate) -> URL? {
        let urlString = "maps://?saddr=\(coord(origin))&daddr=\(coord(destination))&dirflg=d"
        return URL(string: urlString)
    }

    // MARK: - Waypoint Selection

    private static func strategicWaypoints(from coordinates: [Coordinate], count: Int = 3) -> [Coordinate] {
        guard coordinates.count >= 5 else { return [] }
        return (1...count).map { i in
            coordinates[coordinates.count * i / (count + 1)]
        }
    }

    private static func coord(_ c: Coordinate) -> String {
        String(format: "%.6f,%.6f", c.latitude, c.longitude)
    }
}
