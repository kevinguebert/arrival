import Foundation
import Combine

@MainActor
final class MockTrafficProvider: ObservableObject, TrafficProvider {
    // MARK: - Configurable State

    @Published var travelTimeMinutes: Double = 25
    @Published var normalTimeMinutes: Double = 25
    @Published var includeIncidents: Bool = false
    @Published var includeCongestion: Bool = false
    @Published var incidentCount: Int = 2
    @Published var maxSeverity: IncidentSeverity = .major
    @Published var alternateRouteCount: Int = 2
    @Published var alternateDelayMinutes: Double = 8

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

    func fetchRoutes(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
        buildRoutes()
    }

    // MARK: - Route Building

    func buildRoutes() -> RouteResult {
        let travelTime = travelTimeMinutes * 60
        let normalTime = normalTimeMinutes * 60

        let primaryRoute = Route(
            name: "via I-285 S",
            travelTime: travelTime,
            normalTravelTime: normalTime,
            distance: 20_000,
            polylineCoordinates: Self.samplePolyline,
            mkPolyline: nil,
            advisoryNotices: includeIncidents ? ["Construction on main route"] : [],
            segmentCongestion: nil
        )

        var routes = [primaryRoute]

        let altNames = ["via Peachtree Rd", "via GA-400 N"]
        for i in 0..<min(alternateRouteCount, altNames.count) {
            let altDelay = alternateDelayMinutes * Double(i + 1)
            let altRoute = Route(
                name: altNames[i],
                travelTime: travelTime + altDelay * 60,
                normalTravelTime: normalTime + altDelay * 60,
                distance: 20_000 + Double((i + 1) * 2000),
                polylineCoordinates: Self.samplePolyline,
                mkPolyline: nil,
                advisoryNotices: [],
                segmentCongestion: nil
            )
            routes.append(altRoute)
        }

        return RouteResult(
            routes: routes,
            incidents: includeIncidents ? generateIncidents() : [],
            fetchedAt: Date()
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
