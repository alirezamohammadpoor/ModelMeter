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

            Button(action: openSettings) {
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

    private func openSettings() {
        if let appDelegate = AppDelegate.shared {
            appDelegate.openSettingsWindow()
            return
        }
        NSLog("openSettings: AppDelegate.shared is nil, using fallback")
        NSApp.activate(ignoringOtherApps: true)
        let openedSwiftUISettings = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if openedSwiftUISettings { return }
        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}
