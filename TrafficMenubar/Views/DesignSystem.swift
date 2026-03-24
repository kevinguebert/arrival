import SwiftUI

// MARK: - Traffic Mood

/// The emotional state of your commute — drives color, copy, and vibe.
enum TrafficMood {
    case clear       // No delays, smooth sailing
    case moderate    // Some delay, manageable
    case heavy       // Significant delay, incidents likely
    case unknown     // No data yet

    init(delayMinutes: Int, hasIncidents: Bool) {
        if hasIncidents || delayMinutes >= 15 {
            self = .heavy
        } else if delayMinutes >= 5 {
            self = .moderate
        } else {
            self = .clear
        }
    }

    var accentColor: Color {
        switch self {
        case .clear:    return Color(red: 0.30, green: 0.85, blue: 0.55)  // Minty green
        case .moderate: return Color(red: 1.0, green: 0.76, blue: 0.28)   // Warm amber
        case .heavy:    return Color(red: 1.0, green: 0.42, blue: 0.42)   // Soft red
        case .unknown:  return Color.white.opacity(0.5)
        }
    }

    var backgroundTint: Color {
        switch self {
        case .clear:    return Color(red: 0.30, green: 0.85, blue: 0.55).opacity(0.06)
        case .moderate: return Color(red: 1.0, green: 0.76, blue: 0.28).opacity(0.06)
        case .heavy:    return Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.06)
        case .unknown:  return Color.clear
        }
    }

    var moodEmoji: String {
        switch self {
        case .clear:    return "☀️"
        case .moderate: return "🌤"
        case .heavy:    return "🌧"
        case .unknown:  return "🔮"
        }
    }

    var moodPhrase: String {
        switch self {
        case .clear:    return "Smooth sailing"
        case .moderate: return "A bit sluggish"
        case .heavy:    return "Buckle up"
        case .unknown:  return "Checking the roads..."
        }
    }

    var menuBarSuffix: String {
        switch self {
        case .clear:    return ""
        case .moderate: return " ◑"
        case .heavy:    return " ⚠"
        case .unknown:  return ""
        }
    }
}

// MARK: - Design Constants

enum Design {
    static let popoverWidth: CGFloat = 320
    static let popoverPadding: CGFloat = 20
    static let mapHeight: CGFloat = 150
    static let cornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 8

    // Typography — base sizes
    static let heroTimeSize: CGFloat = 48
    static let heroUnitSize: CGFloat = 20
    static let etaValueSize: CGFloat = 22
    static let labelSize: CGFloat = 11
    static let captionSize: CGFloat = 11
    static let moodSize: CGFloat = 12

    // Scaled font helpers
    static func heroTimeFont(scale: CGFloat = 1.0) -> Font {
        .system(size: heroTimeSize * scale, weight: .bold, design: .rounded)
    }
    static func heroUnitFont(scale: CGFloat = 1.0) -> Font {
        .system(size: heroUnitSize * scale, weight: .medium, design: .rounded)
    }
    static func etaValueFont(scale: CGFloat = 1.0) -> Font {
        .system(size: etaValueSize * scale, weight: .semibold, design: .rounded)
    }
    static func labelFont(scale: CGFloat = 1.0) -> Font {
        .system(size: labelSize * scale, weight: .semibold, design: .rounded)
    }
    static func captionFont(scale: CGFloat = 1.0) -> Font {
        .system(size: captionSize * scale, weight: .regular, design: .rounded)
    }
    static func moodFont(scale: CGFloat = 1.0) -> Font {
        .system(size: moodSize * scale, weight: .medium, design: .rounded)
    }
}

// MARK: - Whimsical Empty States

enum EmptyState {
    static let noRoute = (
        icon: "car.side",
        title: "Where to?",
        subtitle: "Set up your addresses in Preferences to get started."
    )

    static let loading = (
        icon: "binoculars",
        title: "Scouting the roads...",
        subtitle: "Hang tight, checking traffic for you."
    )

    static let error = (
        icon: "cloud.bolt",
        title: "Lost signal",
        subtitle: "Can't reach the traffic gods. Will retry shortly."
    )
}
