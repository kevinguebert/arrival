import Foundation
import Combine

@MainActor
final class CommuteViewModel: ObservableObject {
    @Published var currentRoute: RouteResult?
    @Published var direction: CommuteDirection = .toWork
    @Published var isLoading = false
    @Published var consecutiveFailures = 0
    @Published var lastUpdated: Date?
    @Published var directionOverride: CommuteDirection?

    let settings: SettingsStore
    let locationManager: LocationManager
    private let provider: TrafficProvider
    private var scheduler: PollScheduler?

    init(settings: SettingsStore = .shared,
         locationManager: LocationManager = LocationManager(),
         provider: TrafficProvider = MapKitProvider()) {
        self.settings = settings
        self.locationManager = locationManager
        self.provider = provider
    }

    func startPolling() {
        locationManager.requestAuthorization()

        scheduler = PollScheduler(settings: settings) { [weak self] in
            await self?.fetchRoute()
        }
        scheduler?.start()

        Task { await fetchRoute() }
    }

    func stopPolling() {
        scheduler?.stop()
    }

    func refreshNow() {
        scheduler?.pollNow()
    }

    func setDirectionOverride(_ override: CommuteDirection?) {
        directionOverride = override
        Task { await fetchRoute() }
    }

    var menuBarText: String {
        guard let route = currentRoute else {
            return "--m"
        }
        let minutes = route.travelTimeMinutes
        let warning = route.hasIncidents ? " ⚠" : ""
        return "\(minutes)m\(warning)"
    }

    var hasError: Bool {
        consecutiveFailures >= 3
    }

    var timeSinceUpdate: String? {
        guard let lastUpdated else { return nil }
        let seconds = Date().timeIntervalSince(lastUpdated)
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "Updated just now" }
        return "Updated \(minutes)m ago"
    }

    private func fetchRoute() async {
        guard settings.isConfigured,
              let home = settings.homeCoordinate,
              let work = settings.workCoordinate else {
            return
        }

        locationManager.requestLocation()
        let detectedDirection = resolveDirection(home: home, work: work)
        direction = detectedDirection

        let origin: Coordinate
        let destination: Coordinate
        switch detectedDirection {
        case .toWork:
            origin = home
            destination = work
        case .toHome:
            origin = work
            destination = home
        }

        isLoading = currentRoute == nil
        do {
            let result = try await provider.fetchRoute(from: origin, to: destination)
            currentRoute = result
            consecutiveFailures = 0
            lastUpdated = Date()
        } catch {
            consecutiveFailures += 1
        }
        isLoading = false
    }

    private func resolveDirection(home: Coordinate, work: Coordinate) -> CommuteDirection {
        if let override = directionOverride {
            return override
        }

        if let detected = locationManager.detectDirection(home: home, work: work) {
            return detected
        }

        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? .toWork : .toHome
    }
}
