import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private let proximityThreshold: CLLocationDistance = 500

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorized else {
            return
        }
        manager.requestLocation()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    func detectDirection(home: Coordinate, work: Coordinate) -> CommuteDirection? {
        guard let location = currentLocation else { return nil }

        let homeCL = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let workCL = CLLocation(latitude: work.latitude, longitude: work.longitude)

        let distanceToHome = location.distance(from: homeCL)
        let distanceToWork = location.distance(from: workCL)

        if distanceToHome <= proximityThreshold {
            return .toWork
        } else if distanceToWork <= proximityThreshold {
            return .toHome
        }

        return nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently ignore — fallback to time-based detection
    }
}
