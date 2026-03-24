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

    var darkAccentColor: Color {
        switch self {
        case .clear:    return Color(red: 0.29, green: 0.68, blue: 0.50)
        case .moderate: return Color(red: 0.98, green: 0.75, blue: 0.14)
        case .heavy:    return Color(red: 0.97, green: 0.44, blue: 0.44)
        case .unknown:  return Color(red: 0.58, green: 0.64, blue: 0.72)
        }
    }

    var lightTextColor: Color {
        switch self {
        case .clear:    return Color(red: 0.09, green: 0.64, blue: 0.29)
        case .moderate: return Color(red: 0.85, green: 0.47, blue: 0.02)
        case .heavy:    return Color(red: 0.86, green: 0.15, blue: 0.15)
        case .unknown:  return Color(red: 0.39, green: 0.45, blue: 0.55)
        }
    }

    var accentGradientEnd: Color {
        switch self {
        case .clear:    return Color(red: 0.13, green: 0.77, blue: 0.37)
        case .moderate: return Color(red: 0.96, green: 0.62, blue: 0.04)
        case .heavy:    return Color(red: 0.94, green: 0.27, blue: 0.27)
        case .unknown:  return Color(red: 0.39, green: 0.45, blue: 0.55)
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

    var moodPhrases: [String] {
        switch self {
        case .clear:
            return [
                "Smooth sailing", "Open road vibes", "Not a car in sight",
                "Cruising along", "Highway's all yours", "Ghost town out there",
                "Breezing through", "Like a Sunday drive", "Green lights all day",
                "Wind in your hair", "The road is your oyster",
                "Zero drama today", "Practically teleporting", "Speed demon mode",
                "Fast lane energy", "Born to cruise", "All clear, captain",
                "Zoom zoom zoom", "The highway gods smile", "Rolling like butter",
                "Not a brake light in sight", "Main character energy"
            ]
        case .moderate:
            return [
                "A bit sluggish", "Dragging a little", "Could be worse",
                "Patience, grasshopper", "Slow and steady", "Taking its sweet time",
                "Not great, not terrible", "Hitting some molasses", "Rush hour vibes",
                "The scenic pace", "Everyone had the same idea",
                "Bumper to bumper-ish", "Mildly inconvenient", "Sipping coffee pace",
                "The universe says chill", "Easy on the gas", "A gentle crawl",
                "Turtle mode engaged", "Somebody hit the brakes", "Coasting along",
                "Just vibing in traffic", "Zen and the art of commuting"
            ]
        case .heavy:
            return [
                "Buckle up, buttercup", "Gonna be a minute", "Pour another coffee",
                "Yikes on bikes", "It's a parking lot", "Send snacks",
                "Abandon all hope", "Netflix in the car time", "Bring a podcast",
                "Might wanna leave early", "RIP your ETA",
                "Chaos on wheels", "This is fine (it's not)", "Pray for green lights",
                "Time to learn patience", "Call in late", "The highway is a lie",
                "Park it, we're walking", "Snail mail is faster", "Plot twist: we're stuck",
                "Cancel everything", "Goodbye, punctuality"
            ]
        case .unknown:
            return [
                "Scouting the roads...", "Checking the vibes...",
                "Asking the traffic gods...", "Hold tight...",
                "Poking around out there...", "Consulting the oracle...",
                "Summoning traffic data...", "Warming up the satellites...",
                "One sec, peeking outside...", "Phoning a friend...",
                "Dusting off the crystal ball...", "Interrogating the GPS...",
                "Bribing the traffic lights...", "Reading the tea leaves...",
                "Sending out a scout...", "Pinging the mothership...",
                "Shaking the magic 8-ball...", "Eavesdropping on Waze...",
                "Decoding traffic runes...", "Asking the pigeons..."
            ]
        }
    }

    func randomPhrase() -> String {
        moodPhrases.randomElement() ?? moodPhrases[0]
    }

    var menuBarSuffix: String {
        switch self {
        case .clear:    return " ●"
        case .moderate: return " ▲"
        case .heavy:    return " ‼"
        case .unknown:  return ""
        }
    }

    var pulseDuration: Double {
        switch self {
        case .clear:    return 3.0
        case .moderate: return 2.0
        case .heavy:    return 1.2
        case .unknown:  return 2.5
        }
    }

    var pulseScale: CGFloat {
        switch self {
        case .clear:    return 1.08
        case .moderate: return 1.12
        case .heavy:    return 1.15
        case .unknown:  return 1.0
        }
    }
}

// MARK: - Design Constants

enum Design {
    static let popoverWidth: CGFloat = 320
    static let popoverPadding: CGFloat = 20
    static let mapHeight: CGFloat = 150
    static let cornerRadius: CGFloat = 8
    static let smallCornerRadius: CGFloat = 6

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

    static let darkBgTop = Color(red: 0.059, green: 0.071, blue: 0.098)
    static let darkBgBottom = Color(red: 0.086, green: 0.106, blue: 0.149)
    static let lightBgTop = Color.white
    static let lightBgBottom = Color(red: 0.973, green: 0.980, blue: 0.984)
    static let darkText = Color(red: 0.102, green: 0.102, blue: 0.180)

    static let routeCardCornerRadius: CGFloat = 6
    static let moodBadgeCornerRadius: CGFloat = 20
    static let routeNameSize: CGFloat = 12
    static let routeTimeSize: CGFloat = 14

    static func routeNameFont(scale: CGFloat = 1.0, isFastest: Bool = true) -> Font {
        .system(size: routeNameSize * scale, weight: isFastest ? .semibold : .medium, design: .rounded)
    }
    static func routeTimeFont(scale: CGFloat = 1.0, isFastest: Bool = true) -> Font {
        .system(size: routeTimeSize * scale, weight: isFastest ? .bold : .semibold, design: .rounded)
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

    static let errorPhrases = [
        "Lost signal",
        "Can't reach the traffic gods",
        "The internet took a detour",
        "Signals crossed, trying again"
    ]

    static let error = (
        icon: "cloud.bolt",
        title: "Lost signal",
        subtitle: "Will retry automatically."
    )

    static let noRoutesFound = (
        icon: "map",
        title: "Hmm, no routes found",
        subtitle: "MapKit shrugged. Try different addresses?"
    )
}
