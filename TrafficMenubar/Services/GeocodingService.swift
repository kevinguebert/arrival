import Foundation
import CoreLocation

final class GeocodingService {
    private let geocoder = CLGeocoder()

    func geocode(address: String) async throws -> Coordinate {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TrafficProviderError.geocodingFailed(address)
        }

        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.geocodeAddressString(address)
        } catch {
            throw TrafficProviderError.geocodingFailed(address)
        }

        guard let location = placemarks.first?.location else {
            throw TrafficProviderError.geocodingFailed(address)
        }

        return Coordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}
