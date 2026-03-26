import Foundation
import Combine

enum MapsApp: String, CaseIterable {
    case googleMaps = "googleMaps"
    case appleMaps = "appleMaps"

    var displayName: String {
        switch self {
        case .googleMaps: return "Google Maps"
        case .appleMaps: return "Apple Maps"
        }
    }
}

enum BaselineCompareMode: String, CaseIterable {
    case bestCase = "bestCase"
    case typical = "typical"

    var displayName: String {
        switch self {
        case .bestCase: return "Best case (no traffic)"
        case .typical: return "Typical traffic"
        }
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var homeAddress: String {
        didSet { UserDefaults.standard.set(homeAddress, forKey: "homeAddress") }
    }
    @Published var workAddress: String {
        didSet { UserDefaults.standard.set(workAddress, forKey: "workAddress") }
    }
    @Published var homeCoordinate: Coordinate? {
        didSet {
            if let coord = homeCoordinate {
                UserDefaults.standard.set(coord.latitude, forKey: "homeLatitude")
                UserDefaults.standard.set(coord.longitude, forKey: "homeLongitude")
            } else {
                UserDefaults.standard.removeObject(forKey: "homeLatitude")
                UserDefaults.standard.removeObject(forKey: "homeLongitude")
            }
        }
    }
    @Published var workCoordinate: Coordinate? {
        didSet {
            if let coord = workCoordinate {
                UserDefaults.standard.set(coord.latitude, forKey: "workLatitude")
                UserDefaults.standard.set(coord.longitude, forKey: "workLongitude")
            } else {
                UserDefaults.standard.removeObject(forKey: "workLatitude")
                UserDefaults.standard.removeObject(forKey: "workLongitude")
            }
        }
    }

    @Published var morningStartHour: Int {
        didSet { UserDefaults.standard.set(morningStartHour, forKey: "morningStartHour") }
    }
    @Published var morningStartMinute: Int {
        didSet { UserDefaults.standard.set(morningStartMinute, forKey: "morningStartMinute") }
    }
    @Published var morningEndHour: Int {
        didSet { UserDefaults.standard.set(morningEndHour, forKey: "morningEndHour") }
    }
    @Published var morningEndMinute: Int {
        didSet { UserDefaults.standard.set(morningEndMinute, forKey: "morningEndMinute") }
    }
    @Published var eveningStartHour: Int {
        didSet { UserDefaults.standard.set(eveningStartHour, forKey: "eveningStartHour") }
    }
    @Published var eveningStartMinute: Int {
        didSet { UserDefaults.standard.set(eveningStartMinute, forKey: "eveningStartMinute") }
    }
    @Published var eveningEndHour: Int {
        didSet { UserDefaults.standard.set(eveningEndHour, forKey: "eveningEndHour") }
    }
    @Published var eveningEndMinute: Int {
        didSet { UserDefaults.standard.set(eveningEndMinute, forKey: "eveningEndMinute") }
    }

    @Published var commutePollingInterval: TimeInterval {
        didSet { UserDefaults.standard.set(commutePollingInterval, forKey: "commutePollingInterval") }
    }
    @Published var offPeakPollingInterval: TimeInterval {
        didSet { UserDefaults.standard.set(offPeakPollingInterval, forKey: "offPeakPollingInterval") }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    @Published var developerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(developerModeEnabled, forKey: "developerModeEnabled") }
    }
    @Published var devAddressOverrideEnabled: Bool {
        didSet { UserDefaults.standard.set(devAddressOverrideEnabled, forKey: "devAddressOverrideEnabled") }
    }
    @Published var devHomeAddress: String {
        didSet { UserDefaults.standard.set(devHomeAddress, forKey: "devHomeAddress") }
    }
    @Published var devWorkAddress: String {
        didSet { UserDefaults.standard.set(devWorkAddress, forKey: "devWorkAddress") }
    }
    @Published var devHomeCoordinate: Coordinate? {
        didSet {
            if let coord = devHomeCoordinate {
                UserDefaults.standard.set(coord.latitude, forKey: "devHomeLatitude")
                UserDefaults.standard.set(coord.longitude, forKey: "devHomeLongitude")
            } else {
                UserDefaults.standard.removeObject(forKey: "devHomeLatitude")
                UserDefaults.standard.removeObject(forKey: "devHomeLongitude")
            }
        }
    }
    @Published var devWorkCoordinate: Coordinate? {
        didSet {
            if let coord = devWorkCoordinate {
                UserDefaults.standard.set(coord.latitude, forKey: "devWorkLatitude")
                UserDefaults.standard.set(coord.longitude, forKey: "devWorkLongitude")
            } else {
                UserDefaults.standard.removeObject(forKey: "devWorkLatitude")
                UserDefaults.standard.removeObject(forKey: "devWorkLongitude")
            }
        }
    }
    @Published var mapboxAPIKey: String {
        didSet { UserDefaults.standard.set(mapboxAPIKey, forKey: "mapboxAPIKey") }
    }
    @Published var mapboxKeySource: String {
        didSet { UserDefaults.standard.set(mapboxKeySource, forKey: "mapboxKeySource") }
    }
    @Published var preferredMapsApp: MapsApp {
        didSet { UserDefaults.standard.set(preferredMapsApp.rawValue, forKey: "preferredMapsApp") }
    }
    @Published var baselineCompareMode: BaselineCompareMode {
        didSet { UserDefaults.standard.set(baselineCompareMode.rawValue, forKey: "baselineCompareMode") }
    }
    @Published var useMapboxBaseline: Bool {
        didSet { UserDefaults.standard.set(useMapboxBaseline, forKey: "useMapboxBaseline") }
    }
    @Published var baselineToWorkTime: TimeInterval? {
        didSet {
            if let time = baselineToWorkTime {
                UserDefaults.standard.set(time, forKey: "baselineToWorkTime")
            } else {
                UserDefaults.standard.removeObject(forKey: "baselineToWorkTime")
            }
        }
    }
    @Published var baselineToHomeTime: TimeInterval? {
        didSet {
            if let time = baselineToHomeTime {
                UserDefaults.standard.set(time, forKey: "baselineToHomeTime")
            } else {
                UserDefaults.standard.removeObject(forKey: "baselineToHomeTime")
            }
        }
    }
    @Published var baselineFetchedAt: Date? {
        didSet {
            if let date = baselineFetchedAt {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "baselineFetchedAt")
            } else {
                UserDefaults.standard.removeObject(forKey: "baselineFetchedAt")
            }
        }
    }

    var effectiveMapboxKey: String? {
        mapboxKeySource != "none" && !mapboxAPIKey.isEmpty ? mapboxAPIKey : nil
    }

    private var devOverrideActive: Bool {
        developerModeEnabled && devAddressOverrideEnabled
    }

    var effectiveHomeAddress: String {
        devOverrideActive ? devHomeAddress : homeAddress
    }

    var effectiveWorkAddress: String {
        devOverrideActive ? devWorkAddress : workAddress
    }

    var effectiveHomeCoordinate: Coordinate? {
        devOverrideActive ? devHomeCoordinate : homeCoordinate
    }

    var effectiveWorkCoordinate: Coordinate? {
        devOverrideActive ? devWorkCoordinate : workCoordinate
    }

    func setMapboxKey(_ key: String, source: String) {
        mapboxAPIKey = key
        mapboxKeySource = source
    }

    func clearMapboxKey() {
        mapboxAPIKey = ""
        mapboxKeySource = "none"
    }

    func clearBaselines() {
        baselineToWorkTime = nil
        baselineToHomeTime = nil
        baselineFetchedAt = nil
    }

    var isConfigured: Bool {
        effectiveHomeCoordinate != nil && effectiveWorkCoordinate != nil
    }

    private init() {
        let defaults = UserDefaults.standard
        self.homeAddress = defaults.string(forKey: "homeAddress") ?? ""
        self.workAddress = defaults.string(forKey: "workAddress") ?? ""

        if defaults.object(forKey: "homeLatitude") != nil {
            self.homeCoordinate = Coordinate(
                latitude: defaults.double(forKey: "homeLatitude"),
                longitude: defaults.double(forKey: "homeLongitude")
            )
        } else {
            self.homeCoordinate = nil
        }

        if defaults.object(forKey: "workLatitude") != nil {
            self.workCoordinate = Coordinate(
                latitude: defaults.double(forKey: "workLatitude"),
                longitude: defaults.double(forKey: "workLongitude")
            )
        } else {
            self.workCoordinate = nil
        }

        self.morningStartHour = defaults.object(forKey: "morningStartHour") as? Int ?? 7
        self.morningStartMinute = defaults.object(forKey: "morningStartMinute") as? Int ?? 0
        self.morningEndHour = defaults.object(forKey: "morningEndHour") as? Int ?? 9
        self.morningEndMinute = defaults.object(forKey: "morningEndMinute") as? Int ?? 30
        self.eveningStartHour = defaults.object(forKey: "eveningStartHour") as? Int ?? 16
        self.eveningStartMinute = defaults.object(forKey: "eveningStartMinute") as? Int ?? 0
        self.eveningEndHour = defaults.object(forKey: "eveningEndHour") as? Int ?? 19
        self.eveningEndMinute = defaults.object(forKey: "eveningEndMinute") as? Int ?? 0

        self.commutePollingInterval = defaults.object(forKey: "commutePollingInterval") as? TimeInterval ?? 180
        self.offPeakPollingInterval = defaults.object(forKey: "offPeakPollingInterval") as? TimeInterval ?? 900

        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.developerModeEnabled = defaults.bool(forKey: "developerModeEnabled")
        self.devAddressOverrideEnabled = defaults.bool(forKey: "devAddressOverrideEnabled")
        self.devHomeAddress = defaults.string(forKey: "devHomeAddress") ?? ""
        self.devWorkAddress = defaults.string(forKey: "devWorkAddress") ?? ""

        if defaults.object(forKey: "devHomeLatitude") != nil {
            self.devHomeCoordinate = Coordinate(
                latitude: defaults.double(forKey: "devHomeLatitude"),
                longitude: defaults.double(forKey: "devHomeLongitude")
            )
        } else {
            self.devHomeCoordinate = nil
        }

        if defaults.object(forKey: "devWorkLatitude") != nil {
            self.devWorkCoordinate = Coordinate(
                latitude: defaults.double(forKey: "devWorkLatitude"),
                longitude: defaults.double(forKey: "devWorkLongitude")
            )
        } else {
            self.devWorkCoordinate = nil
        }

        self.mapboxAPIKey = defaults.string(forKey: "mapboxAPIKey") ?? ""
        self.mapboxKeySource = defaults.string(forKey: "mapboxKeySource") ?? "none"
        self.preferredMapsApp = MapsApp(rawValue: defaults.string(forKey: "preferredMapsApp") ?? "") ?? .googleMaps
        self.baselineCompareMode = BaselineCompareMode(rawValue: defaults.string(forKey: "baselineCompareMode") ?? "") ?? .bestCase
        self.useMapboxBaseline = defaults.object(forKey: "useMapboxBaseline") as? Bool ?? true
        if defaults.object(forKey: "baselineToWorkTime") != nil {
            self.baselineToWorkTime = defaults.double(forKey: "baselineToWorkTime")
        } else {
            self.baselineToWorkTime = nil
        }
        if defaults.object(forKey: "baselineToHomeTime") != nil {
            self.baselineToHomeTime = defaults.double(forKey: "baselineToHomeTime")
        } else {
            self.baselineToHomeTime = nil
        }
        if defaults.object(forKey: "baselineFetchedAt") != nil {
            self.baselineFetchedAt = Date(timeIntervalSince1970: defaults.double(forKey: "baselineFetchedAt"))
        } else {
            self.baselineFetchedAt = nil
        }
    }

    func isCommuteHour(at date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let timeValue = hour * 60 + minute

        let morningStart = morningStartHour * 60 + morningStartMinute
        let morningEnd = morningEndHour * 60 + morningEndMinute
        let eveningStart = eveningStartHour * 60 + eveningStartMinute
        let eveningEnd = eveningEndHour * 60 + eveningEndMinute

        return (timeValue >= morningStart && timeValue <= morningEnd)
            || (timeValue >= eveningStart && timeValue <= eveningEnd)
    }

    var currentPollingInterval: TimeInterval {
        let interval = isCommuteHour() ? commutePollingInterval : offPeakPollingInterval
        return max(60, interval)
    }
}
