import AppKit
import ModelMeterCore
import SwiftUI

struct UsagePopoverView: View {
    @Bindable var viewModel: MenuViewModel

    private var provider: UsageProvider {
        viewModel.selectedProvider
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            if viewModel.hasErrorState {
                errorContent
            } else {
                UsageMetricView(
                    provider: provider,
                    label: "Session",
                    percentText: viewModel.sessionText,
                    percentValue: viewModel.sessionPercentValue,
                    detailText: viewModel.sessionDetailText)
                divider

                UsageMetricView(
                    provider: provider,
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

            UsageActionsView(provider: provider) {
                viewModel.refreshNow()
            }
        }
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ProviderTheme.border(provider), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: ModelMeterLayout.popoverWidth)
        .frame(maxHeight: 380)
        .animation(ModelMeterMotion.themeSwitch, value: provider)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !viewModel.sessionResetText.isEmpty {
                Text(viewModel.sessionResetText)
                    .font(ModelMeterTextStyles.monoCaption())
                    .foregroundStyle(ProviderTheme.secondaryText(provider))
            }

            if !viewModel.weeklyResetText.isEmpty {
                Text(viewModel.weeklyResetText)
                    .font(ModelMeterTextStyles.monoCaption())
                    .foregroundStyle(ProviderTheme.secondaryText(provider))
            }

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .font(ModelMeterTextStyles.secondary())
                    .foregroundStyle(provider == .claude ? ModelMeterColors.claudeError : ProviderTheme.secondaryText(provider))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func staleSection(text: String) -> some View {
        Text(text)
            .font(ModelMeterTextStyles.monoCaption())
            .foregroundStyle(ProviderTheme.secondaryText(provider))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
    }

    private var headerRow: some View {
        HStack {
            Text("USAGE")
                .font(ModelMeterTextStyles.sectionHeader())
                .foregroundStyle(ProviderTheme.secondaryText(provider))
                .tracking(0.5)
            Spacer()
            ProviderSegmentedToggle(
                provider: provider,
                onSelectClaude: { viewModel.selectProvider(.claude) },
                onSelectCodex: { viewModel.selectProvider(.codex) })
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .overlay(divider, alignment: .bottom)
    }

    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.isAuthError ? "Session expired" : "Unable to read usage data")
                .font(ModelMeterTextStyles.body())
                .foregroundStyle(ProviderTheme.primaryText(provider))
            if let errorText = viewModel.errorText {
                Text(errorText)
                    .font(ModelMeterTextStyles.secondary())
                    .foregroundStyle(ProviderTheme.secondaryText(provider))
            }
            if let hint = viewModel.errorHint {
                Text(hint)
                    .font(ModelMeterTextStyles.secondary())
                    .foregroundStyle(ProviderTheme.secondaryText(provider))
            }
            if !viewModel.isAuthError {
                ModelMeterSecondaryButton(title: "Locate manually", provider: provider) {}
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .overlay(divider, alignment: .bottom)
    }

    private var divider: some View {
        Rectangle()
            .fill(ProviderTheme.border(provider))
            .frame(height: 1)
    }
}

private struct ProviderSegmentedToggle: View {
    let provider: UsageProvider
    let onSelectClaude: () -> Void
    let onSelectCodex: () -> Void
    @State private var claudeHover = false
    @State private var codexHover = false

    var body: some View {
        HStack(spacing: 4) {
            providerButton(
                title: "Claude",
                buttonProvider: .claude,
                isActive: provider == .claude,
                isHovering: claudeHover,
                action: onSelectClaude)
            .onHover { claudeHover = $0 }

            providerButton(
                title: "OpenAI",
                buttonProvider: .codex,
                isActive: provider == .codex,
                isHovering: codexHover,
                action: onSelectCodex)
            .onHover { codexHover = $0 }
        }
        .padding(3)
        .background(ProviderTheme.segmentedContainer(provider))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(ProviderTheme.segmentedBorder(provider), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func providerButton(
        title: String,
        buttonProvider: UsageProvider,
        isActive: Bool,
        isHovering: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let activeBackground = ProviderTheme.segmentedActiveBackground(provider)
        let hoverBackground = ProviderTheme.hoverContainer(provider)
        let textColor = isActive ? ProviderTheme.segmentedActiveText(provider) : ProviderTheme.segmentedInactiveText(provider)

        return Button(action: action) {
            ProviderLogo(provider: buttonProvider, tint: textColor)
                .frame(width: 20, height: 20)
            .frame(minWidth: 40, minHeight: 28)
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(isActive ? activeBackground : (isHovering ? hoverBackground : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(title)
        .animation(ModelMeterMotion.hover, value: isHovering)
    }
}

private struct ProviderLogo: View {
    let provider: UsageProvider
    let tint: Color

    var body: some View {
        Group {
            if let image = ProviderLogoAssets.image(for: provider) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: provider == .claude ? "sparkles" : "circle.grid.2x2.fill")
                    .resizable()
                    .scaledToFit()
            }
        }
        .foregroundStyle(tint)
        .frame(width: 18, height: 18)
    }
}

private enum ProviderLogoAssets {
    static func image(for provider: UsageProvider) -> NSImage? {
        switch provider {
        case .claude: return claude
        case .codex: return openAI
        }
    }

    private static let claude = loadAny(named: "claude")
        ?? loadAny(named: "Claude_Logo_3")
    private static let openAI = loadAny(named: "OpenAI-white-monoblossom")
        ?? loadAny(named: "OpenAI-black-monoblossom")

    private static func loadAny(named resource: String) -> NSImage? {
        for ext in ["png", "svg"] {
            let candidates: [URL?] = [
                Bundle.module.url(forResource: resource, withExtension: ext, subdirectory: "Logos"),
                Bundle.module.url(forResource: resource, withExtension: ext)
            ]
            for url in candidates {
                if let url, let image = NSImage(contentsOf: url) {
                    image.isTemplate = true
                    return image
                }
            }
        }
        return nil
    }
}
