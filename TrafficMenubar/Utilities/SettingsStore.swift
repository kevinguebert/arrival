import Foundation
import Combine

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

    var isConfigured: Bool {
        homeCoordinate != nil && workCoordinate != nil
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
