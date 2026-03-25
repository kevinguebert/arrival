import Foundation

final class MapboxDirectionsProvider: TrafficProvider {
    private let apiKey: String
    private let baseURL: String

    init(apiKey: String, baseURL: String = "https://api.mapbox.com") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func fetchRoutes(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult {
        let urlString = "\(baseURL)/directions/v5/mapbox/driving-traffic/"
            + "\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)"
            + "?access_token=\(apiKey)"
            + "&alternatives=true"
            + "&annotations=congestion,duration"
            + "&geometries=polyline6"
            + "&overview=full"

        guard let url = URL(string: urlString) else {
            throw TrafficProviderError.networkError(URLError(.badURL))
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw TrafficProviderError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                throw TrafficProviderError.invalidAPIKey
            }
            if httpResponse.statusCode != 200 {
                throw TrafficProviderError.networkError(
                    URLError(URLError.Code(rawValue: httpResponse.statusCode))
                )
            }
        }

        let directionsResponse: MapboxDirectionsResponse
        do {
            directionsResponse = try JSONDecoder().decode(MapboxDirectionsResponse.self, from: data)
        } catch {
            throw TrafficProviderError.networkError(error)
        }

        guard directionsResponse.code == "Ok", !directionsResponse.routes.isEmpty else {
            throw TrafficProviderError.noRouteFound
        }

        let routes: [Route] = Array(directionsResponse.routes.prefix(3)).enumerated().map { index, mbRoute in
            let coordinates = decodePolyline6(mbRoute.geometry)
            let congestion = combineLegCongestion(mbRoute.legs)
            let name = index == 0 ? "Fastest Route" : "Alternate \(index)"

            return Route(
                name: name,
                travelTime: mbRoute.duration,
                normalTravelTime: mbRoute.durationTypical ?? mbRoute.duration,
                distance: mbRoute.distance,
                polylineCoordinates: coordinates,
                mkPolyline: nil,
                advisoryNotices: extractAdvisories(mbRoute.legs),
                segmentCongestion: congestion
            )
        }

        let sortedRoutes = routes.sorted { $0.travelTime < $1.travelTime }
        let incidents = extractIncidents(from: directionsResponse.routes.first, coordinates: sortedRoutes.first?.polylineCoordinates ?? [])

        return RouteResult(
            routes: sortedRoutes,
            incidents: incidents,
            fetchedAt: Date()
        )
    }

    // MARK: - Polyline6 Decoding

    private func decodePolyline6(_ encoded: String) -> [Coordinate] {
        var coordinates: [Coordinate] = []
        var index = encoded.startIndex
        var lat: Int = 0
        var lng: Int = 0

        while index < encoded.endIndex {
            lat += decodeValue(from: encoded, index: &index)
            lng += decodeValue(from: encoded, index: &index)
            coordinates.append(Coordinate(
                latitude: Double(lat) / 1e6,
                longitude: Double(lng) / 1e6
            ))
        }

        return coordinates
    }

    private func decodeValue(from string: String, index: inout String.Index) -> Int {
        var result = 0
        var shift = 0

        while index < string.endIndex {
            let char = Int(string[index].asciiValue! - 63)
            index = string.index(after: index)
            result |= (char & 0x1F) << shift
            shift += 5
            if char < 0x20 { break }
        }

        return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    }

    // MARK: - Response Mapping Helpers

    private func combineLegCongestion(_ legs: [MapboxLeg]) -> [CongestionLevel] {
        legs.flatMap { leg in
            (leg.annotation?.congestion ?? []).map { raw in
                CongestionLevel(rawValue: raw) ?? .unknown
            }
        }
    }

    private func extractAdvisories(_ legs: [MapboxLeg]) -> [String] {
        legs.flatMap { leg in
            (leg.incidents ?? []).compactMap { $0.description }
        }
    }

    private func extractIncidents(from route: MapboxRoute?, coordinates: [Coordinate]) -> [TrafficIncident] {
        guard let route else { return [] }
        return route.legs.flatMap { leg in
            (leg.incidents ?? []).compactMap { incident -> TrafficIncident? in
                guard let description = incident.description else { return nil }
                let severity: IncidentSeverity
                switch incident.impact {
                case "critical": severity = .severe
                case "major": severity = .major
                default: severity = .minor
                }
                let locationIndex = incident.geometryIndexStart ?? 0
                let location = locationIndex < coordinates.count
                    ? coordinates[locationIndex]
                    : coordinates.first ?? Coordinate(latitude: 0, longitude: 0)
                return TrafficIncident(description: description, severity: severity, location: location)
            }
        }
    }
}
