import Foundation
import MapKit

struct BaselineResult {
    let toWorkTime: TimeInterval
    let toHomeTime: TimeInterval
}

final class BaselineFetcher {

    enum FetchError: Error {
        case networkError(Error)
        case noRouteFound
        case invalidResponse
    }

    // MARK: - Public API

    /// Fetch no-traffic baseline times for both directions.
    /// Uses Mapbox `driving` (non-traffic) profile if key provided, otherwise MapKit.
    static func fetch(
        home: Coordinate,
        work: Coordinate,
        mapboxAPIKey: String?
    ) async throws -> BaselineResult {
        if let key = mapboxAPIKey {
            return try await fetchMapbox(home: home, work: work, apiKey: key)
        }
        return try await fetchMapKit(home: home, work: work)
    }

    // MARK: - Mapbox (non-traffic profile)

    private static func fetchMapbox(
        home: Coordinate,
        work: Coordinate,
        apiKey: String
    ) async throws -> BaselineResult {
        let toWorkTime = try await fetchMapboxDirection(
            from: home, to: work, apiKey: apiKey
        )
        let toHomeTime = try await fetchMapboxDirection(
            from: work, to: home, apiKey: apiKey
        )
        return BaselineResult(toWorkTime: toWorkTime, toHomeTime: toHomeTime)
    }

    private static func fetchMapboxDirection(
        from origin: Coordinate,
        to destination: Coordinate,
        apiKey: String
    ) async throws -> TimeInterval {
        let path = "/directions/v5/mapbox/driving/"
            + "\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)"

        guard var components = URLComponents(string: "https://api.mapbox.com" + path) else {
            throw FetchError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "access_token", value: apiKey),
            URLQueryItem(name: "overview", value: "false"),
        ]

        guard let url = components.url else {
            throw FetchError.invalidResponse
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw FetchError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw FetchError.networkError(
                URLError(URLError.Code(rawValue: httpResponse.statusCode))
            )
        }

        // Minimal decode — we only need duration from the first route
        struct Response: Codable {
            let code: String
            let routes: [RouteEntry]
            struct RouteEntry: Codable {
                let duration: Double
            }
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard decoded.code == "Ok", let firstRoute = decoded.routes.first else {
            throw FetchError.noRouteFound
        }

        return firstRoute.duration
    }

    // MARK: - MapKit fallback

    private static func fetchMapKit(
        home: Coordinate,
        work: Coordinate
    ) async throws -> BaselineResult {
        let toWorkTime = try await fetchMapKitDirection(from: home, to: work)
        let toHomeTime = try await fetchMapKitDirection(from: work, to: home)
        return BaselineResult(toWorkTime: toWorkTime, toHomeTime: toHomeTime)
    }

    private static func fetchMapKitDirection(
        from origin: Coordinate,
        to destination: Coordinate
    ) async throws -> TimeInterval {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
        ))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        ))
        request.transportType = .automobile
        // No departureDate — request baseline estimate without real-time traffic

        let directions = MKDirections(request: request)

        let response: MKDirections.Response
        do {
            response = try await directions.calculate()
        } catch {
            throw FetchError.networkError(error)
        }

        guard let fastest = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
            throw FetchError.noRouteFound
        }

        // MapKit may still include traffic influence. If time seems high,
        // use a distance-based heuristic as fallback (50 km/h average).
        let heuristicTime = fastest.distance / (50.0 * 1000.0 / 3600.0)
        return min(fastest.expectedTravelTime, heuristicTime)
    }
}
