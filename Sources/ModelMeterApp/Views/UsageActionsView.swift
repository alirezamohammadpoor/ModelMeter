import SwiftUI

struct UsageActionsView: View {
    let onRefresh: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var refreshHover = false
    @State private var settingsHover = false

    var body: some View {
        HStack {
            Button(action: onRefresh) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .light))
                    Text("Refresh")
                        .font(VercelTextStyles.secondary())
                }
                .foregroundStyle(refreshHover ? VercelColors.foreground(colorScheme) : VercelColors.accents5(colorScheme))
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .background(refreshHover ? VercelColors.accents1(colorScheme) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
                        .font(VercelTextStyles.secondary())
                }
                .foregroundStyle(settingsHover ? VercelColors.foreground(colorScheme) : VercelColors.accents5(colorScheme))
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .background(settingsHover ? VercelColors.accents1(colorScheme) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
