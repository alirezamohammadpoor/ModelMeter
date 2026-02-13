import ModelMeterCore
import Observation
import SwiftUI

struct SettingsView: View {
    let store: UsageStore
    @Bindable var settings: SettingsStore
    let updateCoordinator: UpdateCoordinator
    @State private var configStatus: String?
    @State private var updateStatusText: String?

    private var provider: UsageProvider {
        settings.selectedProvider
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(ModelMeterTextStyles.body())
                    .foregroundStyle(ProviderTheme.primaryText(provider))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            SettingsSectionHeader(title: "General", provider: provider)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Polling interval")
                        .font(ModelMeterTextStyles.body())
                        .foregroundStyle(ProviderTheme.primaryText(provider))
                    Spacer()
                    PollIntervalSelector(provider: provider, selection: $settings.pollInterval)
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("Provider")
                        .font(ModelMeterTextStyles.body())
                        .foregroundStyle(ProviderTheme.primaryText(provider))
                    Spacer()
                    Picker("Provider", selection: $settings.selectedProvider) {
                        ForEach(UsageProvider.allCases, id: \.self) { provider in
                            Text(provider == .claude ? "Claude" : "OpenAI").tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(.horizontal, 16)

                ModelMeterToggleRow(title: "Launch at login", provider: provider, isOn: $settings.launchAtLogin)
            }
            divider

            SettingsSectionHeader(title: "Notifications", provider: provider)
            VStack(spacing: 0) {
                ModelMeterToggleRow(title: "60% warning", provider: provider, isOn: $settings.notifyAt60)
                ModelMeterToggleRow(title: "80% warning", provider: provider, isOn: $settings.notifyAt80)
                ModelMeterToggleRow(title: "90% critical", provider: provider, isOn: $settings.notifyAt90)
            }
            divider

            SettingsSectionHeader(title: "Advanced", provider: provider)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Config path")
                        .font(ModelMeterTextStyles.secondary())
                        .foregroundStyle(ProviderTheme.secondaryText(provider))
                    ModelMeterFieldBox(text: configPath, provider: provider)
                }
                .padding(.horizontal, 16)

                ModelMeterSecondaryButton(title: "Create default config", provider: provider) {
                    configStatus = createDefaultConfig()
                }
                .padding(.horizontal, 16)

                if let configStatus {
                    Text(configStatus)
                        .font(ModelMeterTextStyles.secondary())
                        .foregroundStyle(ProviderTheme.secondaryText(provider))
                        .padding(.horizontal, 16)
                }

                ModelMeterSecondaryButton(title: "Check for Updates", provider: provider) {
                    Task {
                        let currentVersion = appVersion
                        updateStatusText = "Checking GitHub releases..."
                        let result = await updateCoordinator.checkNow(currentVersion: currentVersion)
                        switch result {
                        case let .upToDate(current):
                            updateStatusText = "You are up to date (v\(current))."
                        case let .updateAvailable(latest):
                            updateStatusText = "New version found (\(latest)). Starting updater..."
                        case let .error(message):
                            updateStatusText = message
                        }
                    }
                }
                .padding(.horizontal, 16)

                if let updateStatusText {
                    Text(updateStatusText)
                        .font(ModelMeterTextStyles.secondary())
                        .foregroundStyle(ProviderTheme.secondaryText(provider))
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
        }
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ProviderTheme.border(provider), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: 400)
        .animation(ModelMeterMotion.themeSwitch, value: provider)
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
        let fileManager = FileManager.default
        let resourceRoots = [
            Bundle.module.resourceURL,
            Bundle.main.resourceURL
        ]

        for root in resourceRoots {
            guard let root else { continue }
            let candidates = [
                root.appendingPathComponent("ModelMeterScripts", isDirectory: true).appendingPathComponent(fileName),
                root.appendingPathComponent(fileName)
            ]
            for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }

        return nil
    }

    private var configPath: String {
        ConfigStore.defaultURL().path
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = (info["CFBundleShortVersionString"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let short, !short.isEmpty {
            return short
        }
        let build = (info["CFBundleVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (build?.isEmpty == false) ? build! : "dev"
    }

    private var divider: some View {
        Rectangle()
            .fill(ProviderTheme.border(provider))
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}
