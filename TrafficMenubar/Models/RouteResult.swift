import Foundation

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

struct RouteResult {
    let travelTime: TimeInterval
    let normalTravelTime: TimeInterval
    let eta: Date
    let incidents: [TrafficIncident]
    let routePolyline: [Coordinate]

    var delayMinutes: Int {
        let delay = travelTime - normalTravelTime
        return max(0, Int(delay / 60))
    }

    var travelTimeMinutes: Int {
        Int(travelTime / 60)
    }

    var hasIncidents: Bool {
        !incidents.isEmpty
    }
}
