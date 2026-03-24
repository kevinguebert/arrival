import Foundation
import MapKit

struct Coordinate: Equatable, Codable {
    let latitude: Double
    let longitude: Double
}

enum IncidentSeverity: String, Codable {
    case minor
    case major
    case severe
}

struct TrafficIncident: Equatable, Codable {
    let description: String
    let severity: IncidentSeverity
    let location: Coordinate
}

struct Route: Identifiable {
    let id = UUID()
    let name: String
    let travelTime: TimeInterval
    let normalTravelTime: TimeInterval
    let distance: CLLocationDistance
    let polylineCoordinates: [Coordinate]
    let mkPolyline: MKPolyline?
    let advisoryNotices: [String]

    var travelTimeMinutes: Int { Int(travelTime / 60) }
    var delayMinutes: Int { max(0, Int((travelTime - normalTravelTime) / 60)) }
    var eta: Date { Date().addingTimeInterval(travelTime) }
    var hasIncidents: Bool { !advisoryNotices.isEmpty }
}

struct RouteResult {
    let routes: [Route]
    let incidents: [TrafficIncident]
    let fetchedAt: Date

    var fastestRoute: Route? { routes.first }
    var hasAlternates: Bool { routes.count > 1 }

    var shouldCollapse: Bool {
        guard let fastest = fastestRoute else { return true }
        return routes.allSatisfy { abs($0.travelTimeMinutes - fastest.travelTimeMinutes) <= 2 }
    }
}
