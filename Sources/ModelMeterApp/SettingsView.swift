import ModelMeterCore
import Observation
import SwiftUI

struct SettingsView: View {
    let store: UsageStore
    @Bindable var settings: SettingsStore
    @State private var updateManager = UpdateManager.shared
    @State private var configStatus: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(ModelMeterTextStyles.body())
                    .foregroundStyle(SettingsTheme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            SettingsSectionHeader(title: "General")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Polling interval")
                        .font(ModelMeterTextStyles.body())
                        .foregroundStyle(SettingsTheme.primaryText)
                    Spacer()
                    PollIntervalSelector(selection: $settings.pollInterval)
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("Provider")
                        .font(ModelMeterTextStyles.body())
                        .foregroundStyle(SettingsTheme.primaryText)
                    Spacer()
                    SettingsProviderPicker(selection: $settings.selectedProvider)
                }
                .padding(.horizontal, 16)

                ModelMeterToggleRow(title: "Launch at login", isOn: $settings.launchAtLogin)
            }
            divider

            SettingsSectionHeader(title: "Notifications")
            VStack(spacing: 0) {
                ModelMeterToggleRow(title: "60% warning", isOn: $settings.notifyAt60)
                ModelMeterToggleRow(title: "80% warning", isOn: $settings.notifyAt80)
                ModelMeterToggleRow(title: "90% critical", isOn: $settings.notifyAt90)
            }
            divider

            SettingsSectionHeader(title: "Advanced")
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Config path")
                        .font(ModelMeterTextStyles.secondary())
                        .foregroundStyle(SettingsTheme.secondaryText)
                    ModelMeterFieldBox(text: configPath)
                }
                .padding(.horizontal, 16)

                ModelMeterSecondaryButton(title: "Create default config") {
                    configStatus = createDefaultConfig()
                }
                .padding(.horizontal, 16)

                if let configStatus {
                    Text(configStatus)
                        .font(ModelMeterTextStyles.secondary())
                        .foregroundStyle(SettingsTheme.secondaryText)
                        .padding(.horizontal, 16)
                }

                ModelMeterSecondaryButton(title: "Check for Updates") {
                    updateManager.checkForUpdates()
                }
                .disabled(updateManager.isChecking)
                .padding(.horizontal, 16)

                if !updateManager.statusText.isEmpty {
                    Text(updateManager.statusText)
                        .font(ModelMeterTextStyles.secondary())
                        .foregroundStyle(SettingsTheme.secondaryText)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 8)

            Text("ModelMeter v\(UpdateManager.appVersion)")
                .font(ModelMeterTextStyles.secondary())
                .foregroundStyle(SettingsTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .background(SettingsTheme.windowBackground)
        .borderedRounded(SettingsTheme.border, radius: 10)
        .frame(width: 400)
    }

    private func createDefaultConfig() -> String {
        let claudePath = bundledScriptPath(fileName: "claude_usage.py")
        let codexPath = bundledScriptPath(fileName: "codex_usage.py")
        let claudeExists = claudePath != nil
        let codexExists = codexPath != nil

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

    private func bundledScriptPath(fileName: String) -> String? {
        BundleResourceLocator.bundledScriptPath(fileName: fileName)
    }

    private var configPath: String {
        ConfigStore.defaultURL().path
    }

    private var divider: some View {
        Rectangle()
            .fill(SettingsTheme.border)
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}
