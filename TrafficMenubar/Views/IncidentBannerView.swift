import SwiftUI

struct IncidentBannerView: View {
    let incidents: [TrafficIncident]
    let delayMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(incidents.prefix(3).enumerated()), id: \.offset) { _, incident in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(incident.description)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            if delayMinutes > 0 {
                Text("+\(delayMinutes) min vs usual")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(width: 3)
                .foregroundColor(.red),
            alignment: .leading
        )
        .cornerRadius(6)
    }
}
