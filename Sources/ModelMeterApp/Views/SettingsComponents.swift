import SwiftUI
import ModelMeterCore

struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(ModelMeterTextStyles.sectionHeader())
            .foregroundStyle(SettingsTheme.sectionHeader)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

struct ModelMeterToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(ModelMeterTextStyles.body())
                .foregroundStyle(SettingsTheme.primaryText)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(ModelMeterToggleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct ModelMeterToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let trackColor = configuration.isOn ? SettingsTheme.toggleTrackOn : SettingsTheme.toggleTrackOff
        let knobColor = configuration.isOn ? SettingsTheme.toggleKnobOn : SettingsTheme.toggleKnobOff

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
    @Binding var selection: PollIntervalOption
    @State private var hovered: PollIntervalOption?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PollIntervalOption.allCases) { option in
                let isActive = selection == option
                let isHovered = hovered == option && !isActive
                Button(option.label) {
                    selection = option
                }
                .font(ModelMeterTextStyles.body())
                .foregroundStyle(isActive ? SettingsTheme.segmentedActiveText : SettingsTheme.segmentedInactive)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? SettingsTheme.segmentedActive : isHovered ? SettingsTheme.segmentedActive.opacity(0.5) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onHover { hovering in hovered = hovering ? option : nil }
            }
        }
        .padding(4)
    }
}

struct ModelMeterFieldBox: View {
    let text: String

    var body: some View {
        Text(text)
            .font(ModelMeterTextStyles.monoData())
            .foregroundStyle(SettingsTheme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SettingsTheme.fieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(SettingsTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ModelMeterSecondaryButton: View {
    let title: String
    var provider: UsageProvider? = nil
    let action: () -> Void

    var body: some View {
        Button(title) {
            action()
        }
        .buttonStyle(.plain)
        .font(ModelMeterTextStyles.body())
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(provider == nil ? SettingsTheme.buttonBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var foregroundColor: Color {
        if let provider {
            return ProviderTheme.secondaryText(provider)
        }
        return SettingsTheme.buttonText
    }

    private var borderColor: Color {
        if let provider {
            return ProviderTheme.border(provider)
        }
        return SettingsTheme.border
    }
}

struct SettingsProviderPicker: View {
    @Binding var selection: UsageProvider
    @State private var hovered: UsageProvider?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(UsageProvider.allCases, id: \.self) { option in
                let isActive = selection == option
                let isHovered = hovered == option && !isActive
                Button(option == .claude ? "Claude" : "OpenAI") {
                    selection = option
                }
                .font(ModelMeterTextStyles.body())
                .foregroundStyle(isActive ? SettingsTheme.segmentedActiveText : SettingsTheme.segmentedInactive)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? SettingsTheme.segmentedActive : isHovered ? SettingsTheme.segmentedActive.opacity(0.5) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onHover { hovering in hovered = hovering ? option : nil }
            }
        }
        .padding(4)
    }
}
