import Foundation

// MARK: - Mapbox Directions API v5 Response Models

struct MapboxDirectionsResponse: Codable {
    let code: String
    let routes: [MapboxRoute]
}

struct MapboxRoute: Codable {
    let duration: Double
    let durationTypical: Double?
    let distance: Double
    let geometry: String
    let legs: [MapboxLeg]

    enum CodingKeys: String, CodingKey {
        case duration, distance, geometry, legs
        case durationTypical = "duration_typical"
    }
}

struct MapboxLeg: Codable {
    let annotation: MapboxAnnotation?
    let incidents: [MapboxIncident]?
}

struct MapboxAnnotation: Codable {
    let congestion: [String]?
    let duration: [Double]?
}

struct MapboxIncident: Codable {
    let description: String?
    let impact: String?
    let geometryIndexStart: Int?
    let geometryIndexEnd: Int?

    enum CodingKeys: String, CodingKey {
        case description, impact
        case geometryIndexStart = "geometry_index_start"
        case geometryIndexEnd = "geometry_index_end"
    }
}
