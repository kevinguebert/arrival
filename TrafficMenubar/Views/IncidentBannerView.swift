import SwiftUI

struct IncidentBannerView: View {
    let incidents: [TrafficIncident]
    let delayMinutes: Int
    @Environment(\.devDesignOverrides) private var designOverrides

    private var fontScale: CGFloat {
        designOverrides?.fontScale ?? 1.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "cone.striped")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))

                Text(headerText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }

            // Incident list
            ForEach(Array(incidents.prefix(3).enumerated()), id: \.offset) { _, incident in
                HStack(spacing: 6) {
                    Circle()
                        .fill(severityColor(incident.severity))
                        .frame(width: 5, height: 5)

                    Text(incident.description)
                        .font(Design.captionFont(scale: fontScale))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 2)
            }

            if incidents.count > 3 {
                Text("+ \(incidents.count - 3) more")
                    .font(Design.captionFont(scale: fontScale))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Design.smallCornerRadius)
                .fill(Color.red.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.smallCornerRadius)
                        .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var headerText: String {
        let count = incidents.count
        if count == 1 {
            return "1 incident ahead"
        }
        return "\(count) incidents ahead"
    }

    private func severityColor(_ severity: IncidentSeverity) -> Color {
        switch severity {
        case .minor:  return .orange
        case .major:  return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .severe: return .red
        }
    }
}
