import Foundation
import Combine

@MainActor
final class MockTrafficProvider: ObservableObject, TrafficProvider {
    // MARK: - Configurable State

    @Published var travelTimeMinutes: Double = 25
    @Published var normalTimeMinutes: Double = 25
    @Published var includeIncidents: Bool = false
    @Published var incidentCount: Int = 2
    @Published var maxSeverity: IncidentSeverity = .major

    // MARK: - Sample Data

    static let samplePolyline: [Coordinate] = [
        Coordinate(latitude: 37.7749, longitude: -122.4194),
        Coordinate(latitude: 37.7755, longitude: -122.4170),
        Coordinate(latitude: 37.7765, longitude: -122.4145),
        Coordinate(latitude: 37.7780, longitude: -122.4120),
        Coordinate(latitude: 37.7800, longitude: -122.4100),
        Coordinate(latitude: 37.7820, longitude: -122.4085),
        Coordinate(latitude: 37.7845, longitude: -122.4070),
        Coordinate(latitude: 37.7870, longitude: -122.4060),
        Coordinate(latitude: 37.7895, longitude: -122.4055),
        Coordinate(latitude: 37.7920, longitude: -122.4050),
        Coordinate(latitude: 37.7945, longitude: -122.4048),
        Coordinate(latitude: 37.7970, longitude: -122.4045),
        Coordinate(latitude: 37.7990, longitude: -122.4040),
        Coordinate(latitude: 37.8010, longitude: -122.4035),
        Coordinate(latitude: 37.8030, longitude: -122.4025),
        Coordinate(latitude: 37.8050, longitude: -122.4010),
        Coordinate(latitude: 37.8065, longitude: -122.3995),
        Coordinate(latitude: 37.8080, longitude: -122.3975),
        Coordinate(latitude: 37.8090, longitude: -122.3955),
        Coordinate(latitude: 37.8095, longitude: -122.3935),
    ]

    // MARK: - TrafficProvider Conformance

    func fetchRoute(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
        buildRoute()
    }

    // MARK: - Route Building

    func buildRoute() -> RouteResult {
        let travelTime = travelTimeMinutes * 60
        let normalTime = normalTimeMinutes * 60

        let incidents: [TrafficIncident]
        if includeIncidents {
            incidents = generateIncidents()
        } else {
            incidents = []
        }

        return RouteResult(
            travelTime: travelTime,
            normalTravelTime: normalTime,
            eta: Date().addingTimeInterval(travelTime),
            incidents: incidents,
            routePolyline: Self.samplePolyline
        )
    }

    private func generateIncidents() -> [TrafficIncident] {
        let templates: [(IncidentSeverity, String)] = [
            (.minor, "Minor slowdown ahead"),
            (.major, "Construction on main route"),
            (.severe, "Major accident — expect significant delays"),
        ]

        let filtered = templates.filter { severity, _ in
            switch maxSeverity {
            case .minor: return severity == .minor
            case .major: return severity == .minor || severity == .major
            case .severe: return true
            }
        }

        let count = min(incidentCount, filtered.count)
        return (0..<count).map { index in
            let (severity, description) = filtered[index % filtered.count]
            let polylineIndex = min(index * 5 + 3, Self.samplePolyline.count - 1)
            return TrafficIncident(
                description: description,
                severity: severity,
                location: Self.samplePolyline[polylineIndex]
            )
        }
    }
}
