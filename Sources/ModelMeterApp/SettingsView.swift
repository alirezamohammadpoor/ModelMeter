import ModelMeterCore
import Observation
import SwiftUI

struct SettingsView: View {
    let store: UsageStore
    @Bindable var settings: SettingsStore
    @State private var configStatus: String?
    @State private var claudeCookieHeader: String = ""
    @State private var cookieStatus: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(VercelTextStyles.body())
                    .foregroundStyle(VercelColors.foreground(colorScheme))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            SettingsSectionHeader(title: "General")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Polling interval")
                        .font(VercelTextStyles.body())
                        .foregroundStyle(VercelColors.foreground(colorScheme))
                    Spacer()
                    PollIntervalSelector(selection: $settings.pollInterval)
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("Provider")
                        .font(VercelTextStyles.body())
                        .foregroundStyle(VercelColors.foreground(colorScheme))
                    Spacer()
                    Picker("Provider", selection: $settings.selectedProvider) {
                        ForEach(UsageProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                .padding(.horizontal, 16)

                VercelToggleRow(title: "Launch at login", isOn: $settings.launchAtLogin)
            }
            divider

            SettingsSectionHeader(title: "Notifications")
            VStack(spacing: 0) {
                VercelToggleRow(title: "60% warning", isOn: $settings.notifyAt60)
                VercelToggleRow(title: "80% warning", isOn: $settings.notifyAt80)
                VercelToggleRow(title: "95% critical", isOn: $settings.notifyAt95)
            }
            divider

            SettingsSectionHeader(title: "Advanced")
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Config path")
                        .font(VercelTextStyles.secondary())
                        .foregroundStyle(VercelColors.accents5(colorScheme))
                    VercelFieldBox(text: configPath)
                }
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Claude web cookie")
                        .font(VercelTextStyles.secondary())
                        .foregroundStyle(VercelColors.accents5(colorScheme))
                    VercelTextArea(placeholder: "Paste Cookie header (sessionKey=...)", text: $claudeCookieHeader)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 8) {
                    VercelSecondaryButton(title: "Save cookie") {
                        cookieStatus = saveClaudeCookie()
                    }

                    VercelSecondaryButton(title: "Clear cookie") {
                        claudeCookieHeader = ""
                        cookieStatus = saveClaudeCookie()
                    }
                }
                .padding(.horizontal, 16)

                VercelSecondaryButton(title: "Create default config") {
                    configStatus = createDefaultConfig()
                }
                .padding(.horizontal, 16)

                if let cookieStatus {
                    Text(cookieStatus)
                        .font(VercelTextStyles.secondary())
                        .foregroundStyle(VercelColors.accents5(colorScheme))
                        .padding(.horizontal, 16)
                }

                if let configStatus {
                    Text(configStatus)
                        .font(VercelTextStyles.secondary())
                        .foregroundStyle(VercelColors.accents5(colorScheme))
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
        }
        .background(VercelColors.background100(colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VercelColors.border(colorScheme), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 400)
        .onAppear {
            claudeCookieHeader = loadClaudeCookie()
        }
    }

    private func createDefaultConfig() -> String {
        let scriptsRoot = Bundle.main.resourceURL?.appendingPathComponent("ModelMeterScripts")

        let claudePath = scriptsRoot?.appendingPathComponent("claude_usage.py").path
        let codexPath = scriptsRoot?.appendingPathComponent("codex_usage.py").path

        let fileManager = FileManager.default
        let claudeExists = (claudePath.flatMap { fileManager.fileExists(atPath: $0) } == true)
        let codexExists = (codexPath.flatMap { fileManager.fileExists(atPath: $0) } == true)

        var config = ModelMeterConfig(source: "command")
        if claudeExists {
            config.claudeCommand = claudePath
        }
        if codexExists {
            config.codexCommand = codexPath
        }

        do {
            try ConfigStore().save(config)
        } catch {
            return "Failed to write config: \(error.localizedDescription)"
        }

        if !claudeExists || !codexExists {
            return "Config saved, but script paths missing. Update ~/.modelmeter/config.json."
        }
        return "Config saved at ~/.modelmeter/config.json."
    }

    private func loadClaudeCookie() -> String {
        guard let config = try? ConfigStore().load() else { return "" }
        return config.claudeCookieHeader ?? ""
    }

    private func saveClaudeCookie() -> String {
        let store = ConfigStore()
        var config = (try? store.load()) ?? ModelMeterConfig(source: "command")
        let trimmed = claudeCookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        config.claudeCookieHeader = trimmed.isEmpty ? nil : trimmed
        do {
            try store.save(config)
        } catch {
            return "Failed to save cookie: \(error.localizedDescription)"
        }
        return trimmed.isEmpty ? "Cookie cleared." : "Cookie saved."
    }

    private var configPath: String {
        ConfigStore.defaultURL().path
    }

    private var divider: some View {
        Rectangle()
            .fill(VercelColors.border(colorScheme))
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}
