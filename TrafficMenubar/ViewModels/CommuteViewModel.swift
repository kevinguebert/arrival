import Foundation
import Combine

@MainActor
final class CommuteViewModel: ObservableObject {
    @Published var currentResult: RouteResult?
    @Published var direction: CommuteDirection = .toWork
    @Published var isLoading = false
    @Published var consecutiveFailures = 0
    @Published var lastUpdated: Date?
    @Published var directionOverride: CommuteDirection?
    @Published var isDevMode = false
    @Published var selectedRouteIndex: Int = 0

    let settings: SettingsStore
    let locationManager: LocationManager
    private(set) var provider: TrafficProvider
    private var settingsCancellable: AnyCancellable?
    private var scheduler: PollScheduler?

    init(settings: SettingsStore = .shared,
         locationManager: LocationManager = LocationManager(),
         provider: TrafficProvider? = nil) {
        self.settings = settings
        self.locationManager = locationManager
        self.provider = provider ?? Self.makeProvider(for: settings)
        settingsCancellable = settings.$mapboxKeySource
            .combineLatest(settings.$mapboxAPIKey)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.provider = Self.makeProvider(for: self.settings)
            }
    }

    private static func makeProvider(for settings: SettingsStore) -> TrafficProvider {
        if let key = settings.effectiveMapboxKey {
            return MapboxDirectionsProvider(apiKey: key)
        }
        return MapKitProvider()
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

    func enableDevMode(mockProvider: MockTrafficProvider) {
        stopPolling()
        provider = mockProvider
        isDevMode = true
    }

    func disableDevMode() {
        provider = Self.makeProvider(for: settings)
        isDevMode = false
        startPolling()
    }

    func updateFromMock(result: RouteResult?, direction: CommuteDirection, consecutiveFailures: Int, isLoading: Bool) {
        self.currentResult = result
        self.direction = direction
        self.consecutiveFailures = consecutiveFailures
        self.isLoading = isLoading
        self.lastUpdated = result != nil ? Date() : nil
    }

    var fastestRoute: Route? { currentResult?.fastestRoute }

    var mood: TrafficMood {
        guard let route = fastestRoute else { return .unknown }

        let baseline: TimeInterval
        switch settings.baselineCompareMode {
        case .typical:
            baseline = route.normalTravelTime
        case .bestCase:
            let persisted = direction == .toWork
                ? settings.baselineToWorkTime
                : settings.baselineToHomeTime
            baseline = persisted ?? route.normalTravelTime
        }

        let hasMajorIncidents = currentResult?.incidents.contains {
            $0.severity == .major || $0.severity == .severe
        } ?? false

        return TrafficMood(
            currentTime: route.travelTime,
            baselineTime: baseline,
            segmentCongestion: route.segmentCongestion,
            hasMajorIncidents: hasMajorIncidents
        )
    }

    var menuBarText: String {
        guard let route = fastestRoute else {
            return "--"
        }
        let minutes = route.travelTimeMinutes
        return "\(minutes)m\(mood.menuBarSuffix)"
    }

    var originCoordinate: Coordinate {
        let home = settings.homeCoordinate ?? Coordinate(latitude: 0, longitude: 0)
        let work = settings.workCoordinate ?? Coordinate(latitude: 0, longitude: 0)
        return direction == .toWork ? home : work
    }

    var destinationCoordinate: Coordinate {
        let home = settings.homeCoordinate ?? Coordinate(latitude: 0, longitude: 0)
        let work = settings.workCoordinate ?? Coordinate(latitude: 0, longitude: 0)
        return direction == .toWork ? work : home
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

        isLoading = currentResult == nil
        do {
            let result = try await provider.fetchRoutes(from: origin, to: destination)
            currentResult = result
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
