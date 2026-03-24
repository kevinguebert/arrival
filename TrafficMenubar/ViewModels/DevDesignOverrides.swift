import SwiftUI
import Combine

final class DevDesignOverrides: ObservableObject {
    @Published var moodOverride: TrafficMood?
    @Published var fontScale: CGFloat = 1.0
}

// MARK: - Environment Key

struct DevDesignOverridesKey: EnvironmentKey {
    static let defaultValue: DevDesignOverrides? = nil
}

extension EnvironmentValues {
    var devDesignOverrides: DevDesignOverrides? {
        get { self[DevDesignOverridesKey.self] }
        set { self[DevDesignOverridesKey.self] = newValue }
    }
}
