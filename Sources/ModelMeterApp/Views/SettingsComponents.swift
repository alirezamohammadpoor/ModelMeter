import SwiftUI
import ModelMeterCore

struct SettingsSectionHeader: View {
    let title: String
    let provider: UsageProvider

    var body: some View {
        Text(title.uppercased())
            .font(ModelMeterTextStyles.sectionHeader())
            .foregroundStyle(ProviderTheme.secondaryText(provider))
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

struct ModelMeterToggleRow: View {
    let title: String
    let provider: UsageProvider
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(ModelMeterTextStyles.body())
                .foregroundStyle(ProviderTheme.primaryText(provider))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(ModelMeterToggleStyle(provider: provider))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct ModelMeterToggleStyle: ToggleStyle {
    let provider: UsageProvider

    func makeBody(configuration: Configuration) -> some View {
        let trackColor = configuration.isOn ? ProviderTheme.accent(provider) : ProviderTheme.progressTrack(provider)
        let knobColor = Color.black.opacity(provider == .codex ? 1 : 0.9)

        return Button(action: {
            configuration.isOn.toggle()
        }) {
            RoundedRectangle(cornerRadius: 11)
                .fill(trackColor)
                .frame(width: 40, height: 22)
                .overlay(
                    Circle()
                        .fill(knobColor)
                        .padding(2)
                        .offset(x: configuration.isOn ? 9 : -9)
                        .animation(ModelMeterMotion.hover, value: configuration.isOn)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PollIntervalSelector: View {
    let provider: UsageProvider
    @Binding var selection: PollIntervalOption

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PollIntervalOption.allCases) { option in
                Button(option.label) {
                    selection = option
                }
                .font(ModelMeterTextStyles.body())
                .foregroundStyle(selection == option ? Color.black : ProviderTheme.primaryText(provider))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selection == option ? ProviderTheme.accent(provider) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(4)
        .background(ProviderTheme.subtleContainer(provider))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ProviderTheme.border(provider), lineWidth: 1)
        )
    }
}

struct ModelMeterFieldBox: View {
    let text: String
    let provider: UsageProvider

    var body: some View {
        Text(text)
            .font(ModelMeterTextStyles.monoData())
            .foregroundStyle(ProviderTheme.primaryText(provider))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ProviderTheme.subtleContainer(provider))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(ProviderTheme.border(provider), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ModelMeterSecondaryButton: View {
    let title: String
    let provider: UsageProvider
    let action: () -> Void

    var body: some View {
        Button(title) {
            action()
        }
        .buttonStyle(.plain)
        .font(ModelMeterTextStyles.body())
        .foregroundStyle(ProviderTheme.secondaryText(provider))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ProviderTheme.border(provider), lineWidth: 1)
        )
    }
}
