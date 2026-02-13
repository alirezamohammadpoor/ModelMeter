import Foundation
import Observation
import ModelMeterCore

enum PollIntervalOption: String, CaseIterable, Identifiable {
    case thirtySeconds
    case oneMinute
    case fiveMinutes

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .thirtySeconds: 30
        case .oneMinute: 60
        case .fiveMinutes: 300
        }
    }

    var label: String {
        switch self {
        case .thirtySeconds: "30s"
        case .oneMinute: "1m"
        case .fiveMinutes: "5m"
        }
    }
}

@MainActor
@Observable
final class SettingsStore {
    private let defaults: UserDefaults

    var pollInterval: PollIntervalOption {
        didSet { persist() }
    }

    var notifyAt60: Bool {
        didSet { persist() }
    }

    var notifyAt80: Bool {
        didSet { persist() }
    }

    var notifyAt90: Bool {
        didSet { persist() }
    }

    var launchAtLogin: Bool {
        didSet {
            persist()
            applyLaunchAtLogin()
        }
    }

    var selectedProvider: UsageProvider {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawInterval = defaults.string(forKey: "pollInterval")
        self.pollInterval = PollIntervalOption(rawValue: rawInterval ?? "") ?? .thirtySeconds
        self.notifyAt60 = defaults.object(forKey: "notifyAt60") as? Bool ?? true
        self.notifyAt80 = defaults.object(forKey: "notifyAt80") as? Bool ?? true
        let notifyAt90 = defaults.object(forKey: "notifyAt90") as? Bool
            ?? defaults.object(forKey: "notifyAt95") as? Bool
            ?? defaults.object(forKey: "notifyAt100") as? Bool
            ?? true
        self.notifyAt90 = notifyAt90
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        let rawProvider = defaults.string(forKey: "selectedProvider")
        self.selectedProvider = UsageProvider(rawValue: rawProvider ?? "") ?? .claude
    }

    func isThresholdEnabled(_ threshold: Int) -> Bool {
        switch threshold {
        case UsageThresholds.warning60: return notifyAt60
        case UsageThresholds.warning80: return notifyAt80
        case UsageThresholds.critical90: return notifyAt90
        default: return false
        }
    }

    private func persist() {
        defaults.set(pollInterval.rawValue, forKey: "pollInterval")
        defaults.set(notifyAt60, forKey: "notifyAt60")
        defaults.set(notifyAt80, forKey: "notifyAt80")
        defaults.set(notifyAt90, forKey: "notifyAt90")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(selectedProvider.rawValue, forKey: "selectedProvider")
    }

    private func applyLaunchAtLogin() {
        do {
            try LaunchAtLoginManager.setEnabled(launchAtLogin)
        } catch {
            // Keep silent for now; expose errors in a future UI.
        }
    }
}
