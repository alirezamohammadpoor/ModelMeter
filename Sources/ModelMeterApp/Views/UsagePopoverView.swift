import ModelMeterCore
import SwiftUI

struct UsagePopoverView: View {
    @Bindable var viewModel: MenuViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        VercelColors.border(colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            if viewModel.hasErrorState {
                errorContent
            } else {
                UsageMetricView(
                    label: "Session",
                    percentText: viewModel.sessionText,
                    percentValue: viewModel.sessionPercentValue,
                    detailText: viewModel.sessionDetailText)
                divider

                UsageMetricView(
                    label: "Weekly",
                    percentText: viewModel.weeklyText,
                    percentValue: viewModel.weeklyPercentValue,
                    detailText: viewModel.weeklyDetailText)
                divider

                metadataSection
            }

            if let staleText = viewModel.staleText {
                staleSection(text: staleText)
            }

            UsageActionsView {
                viewModel.refreshNow()
            }
        }
        .background(VercelColors.background100(colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 280)
        .frame(maxHeight: 360)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !viewModel.sessionResetText.isEmpty {
                Text(viewModel.sessionResetText)
                    .font(VercelTextStyles.secondary())
                    .foregroundStyle(VercelColors.accents5(colorScheme))
            }

            if !viewModel.weeklyResetText.isEmpty {
                Text(viewModel.weeklyResetText)
                    .font(VercelTextStyles.secondary())
                    .foregroundStyle(VercelColors.accents5(colorScheme))
            }

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .font(VercelTextStyles.secondary())
                    .foregroundStyle(VercelColors.error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func staleSection(text: String) -> some View {
        Text(text)
            .font(VercelTextStyles.label())
            .foregroundStyle(VercelColors.accents4(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
    }

    private var headerRow: some View {
        let providerBinding = Binding<UsageProvider>(
            get: { viewModel.settings.selectedProvider },
            set: { viewModel.selectProvider($0) }
        )

        return HStack {
            Text("USAGE")
                .font(VercelTextStyles.sectionHeader())
                .foregroundStyle(VercelColors.accents5(colorScheme))
                .tracking(0.5)
            Spacer()
            Picker("Provider", selection: providerBinding) {
                Text("Claude").tag(UsageProvider.claude)
                Text("Codex").tag(UsageProvider.codex)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .overlay(divider, alignment: .bottom)
    }

    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unable to read usage data")
                .font(VercelTextStyles.body())
                .foregroundStyle(VercelColors.foreground(colorScheme))
            if let errorText = viewModel.errorText {
                Text(errorText)
                    .font(VercelTextStyles.secondary())
                    .foregroundStyle(VercelColors.accents5(colorScheme))
            }
            VercelSecondaryButton(title: "Locate manually") {}
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .overlay(divider, alignment: .bottom)
    }

    private var divider: some View {
        Rectangle()
            .fill(borderColor)
            .frame(height: 1)
    }
}
