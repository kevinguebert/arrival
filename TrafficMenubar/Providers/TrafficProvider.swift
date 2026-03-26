import Foundation

enum TrafficProviderError: Error, LocalizedError {
    case noRouteFound
    case geocodingFailed(String)
    case networkError(Error)
    case invalidAPIKey

    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "No route found between the two locations."
        case .geocodingFailed(let address):
            return "Could not find location for: \(address)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidAPIKey:
            return "Invalid API key. Check your Mapbox key in Settings."
        }
    }
}

protocol TrafficProvider {
    func fetchRoutes(from origin: Coordinate, to destination: Coordinate) async throws -> RouteResult
}
