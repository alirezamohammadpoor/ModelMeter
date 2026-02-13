import SwiftUI
import ModelMeterCore

struct UsageActionsView: View {
    let provider: UsageProvider
    let onRefresh: () -> Void

    @State private var refreshHover = false
    @State private var settingsHover = false

    private var actionForeground: Color {
        ProviderTheme.secondaryText(provider)
    }

    var body: some View {
        HStack {
            Button(action: onRefresh) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .light))
                    Text("Refresh")
                        .font(ModelMeterTextStyles.secondary())
                }
                .foregroundStyle(actionForeground)
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .background(refreshHover ? ProviderTheme.hoverContainer(provider) : ProviderTheme.controlBackground(provider))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .animation(ModelMeterMotion.hover, value: refreshHover)
            }
            .buttonStyle(.plain)
            .onHover { hover in
                refreshHover = hover
            }

            Spacer()

            SettingsLink {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .light))
                    Text("Settings")
                        .font(ModelMeterTextStyles.secondary())
                }
                .foregroundStyle(actionForeground)
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .background(settingsHover ? ProviderTheme.hoverContainer(provider) : ProviderTheme.controlBackground(provider))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .animation(ModelMeterMotion.hover, value: settingsHover)
            }
            .buttonStyle(.plain)
            .onHover { hover in
                settingsHover = hover
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
