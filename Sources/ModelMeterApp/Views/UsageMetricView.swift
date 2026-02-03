import SwiftUI

struct UsageMetricView: View {
    let label: String
    let percentText: String
    let percentValue: Double?
    let detailText: String?

    @Environment(\.colorScheme) private var colorScheme

    private var statusColor: Color {
        guard let percentValue else { return VercelColors.accents5(colorScheme) }
        return VercelStatusColor.forUsagePercent(percentValue).color(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(percentText)
                    .font(VercelTextStyles.metricValue())
                    .foregroundStyle(statusColor)
                Spacer()
                Text(label)
                    .font(VercelTextStyles.label())
                    .foregroundStyle(VercelColors.accents5(colorScheme))
            }

            UsageProgressBar(
                progress: (percentValue ?? 0) / 100.0,
                color: statusColor,
                trackColor: VercelColors.accents2(colorScheme))

            if let detailText {
                Text(detailText)
                    .font(VercelTextStyles.monoCaption())
                    .foregroundStyle(VercelColors.accents4(colorScheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
