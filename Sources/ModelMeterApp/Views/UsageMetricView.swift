import SwiftUI
import ModelMeterCore

struct UsageMetricView: View {
    let provider: UsageProvider
    let label: String
    let percentText: String
    let percentValue: Double?
    let detailText: String?

    private var percentTextColor: Color {
        ProviderTheme.progressFill(provider, percent: percentValue)
    }

    private var progressFillColor: Color {
        ProviderTheme.progressFill(provider, percent: percentValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(percentText)
                    .font(ModelMeterTextStyles.metricValue())
                    .foregroundStyle(percentTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Text(label)
                    .font(ModelMeterTextStyles.label())
                    .foregroundStyle(ProviderTheme.primaryText(provider))
            }

            UsageProgressBar(
                progress: (percentValue ?? 0) / 100.0,
                color: progressFillColor,
                trackColor: ProviderTheme.progressTrack(provider))

            if let detailText {
                Text(detailText)
                    .font(ModelMeterTextStyles.monoCaption())
                    .foregroundStyle(ProviderTheme.secondaryText(provider))
            }
        }
        .padding(.horizontal, ModelMeterLayout.horizontalPadding)
        .padding(.vertical, ModelMeterLayout.verticalPadding)
    }
}
