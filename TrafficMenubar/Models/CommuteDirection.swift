import Foundation

enum CommuteDirection: String, CaseIterable {
    case toWork
    case toHome

    var displayName: String {
        switch self {
        case .toWork: return "Commute to Work"
        case .toHome: return "Commute Home"
        }
    }
}
