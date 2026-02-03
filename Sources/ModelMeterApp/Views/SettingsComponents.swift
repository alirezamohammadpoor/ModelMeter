import SwiftUI

struct SettingsSectionHeader: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title.uppercased())
            .font(VercelTextStyles.sectionHeader())
            .foregroundStyle(VercelColors.accents5(colorScheme))
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

struct VercelToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text(title)
                .font(VercelTextStyles.body())
                .foregroundStyle(VercelColors.foreground(colorScheme))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(VercelToggleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct VercelToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let trackColor = configuration.isOn ? VercelColors.foreground(colorScheme) : VercelColors.accents2(colorScheme)
        let knobColor = VercelColors.background100(colorScheme)

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
                        .animation(.easeOut(duration: 0.15), value: configuration.isOn)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PollIntervalSelector: View {
    @Binding var selection: PollIntervalOption
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PollIntervalOption.allCases) { option in
                Button(option.label) {
                    selection = option
                }
                .font(VercelTextStyles.body())
                .foregroundStyle(selection == option ? VercelColors.background100(colorScheme) : VercelColors.foreground(colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selection == option ? VercelColors.foreground(colorScheme) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(4)
        .background(VercelColors.accents1(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(VercelColors.border(colorScheme), lineWidth: 1)
        )
    }
}

struct VercelFieldBox: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(VercelTextStyles.monoData())
            .foregroundStyle(VercelColors.foreground(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VercelColors.accents1(colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(VercelColors.border(colorScheme), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct VercelTextArea: View {
    let placeholder: String
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(VercelTextStyles.monoCaption())
            .foregroundStyle(VercelColors.foreground(colorScheme))
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VercelColors.accents1(colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(VercelColors.border(colorScheme), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct VercelSecondaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(title) {
            action()
        }
        .buttonStyle(.plain)
        .font(VercelTextStyles.body())
        .foregroundStyle(VercelColors.foreground(colorScheme))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(VercelColors.border(colorScheme), lineWidth: 1)
        )
    }
}
