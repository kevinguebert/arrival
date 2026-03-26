import SwiftUI

struct PulseDotView: View {
    let mood: TrafficMood
    let size: CGFloat

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(mood.darkAccentColor)
            .frame(width: size, height: size)
            .shadow(color: mood.darkAccentColor.opacity(glowOpacity), radius: glowRadius)
            .scaleEffect(isAnimating ? mood.pulseScale : 1.0)
            .opacity(mood == .unknown ? (isAnimating ? 1.0 : 0.4) : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: mood.pulseDuration)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
            .onChange(of: mood) { newMood in
                isAnimating = false
                withAnimation(
                    .easeInOut(duration: newMood.pulseDuration)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }

    private var glowOpacity: Double {
        switch mood {
        case .clear:    return 0.5
        case .moderate: return 0.5
        case .heavy:    return 0.6
        case .unknown:  return 0.3
        }
    }

    private var glowRadius: CGFloat {
        switch mood {
        case .clear:    return 4
        case .moderate: return 5
        case .heavy:    return 6
        case .unknown:  return 3
        }
    }
}
