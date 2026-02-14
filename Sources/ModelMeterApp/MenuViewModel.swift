import Foundation
import ModelMeterCore

@MainActor
@Observable
final class MenuViewModel {
    let store: UsageStore
    let settings: SettingsStore
    private let notifications: NotificationManager
    private var sessionThresholdGates: [UsageProvider: ThresholdGate] = [:]
    private var weeklyThresholdGates: [UsageProvider: ThresholdGate] = [:]

    init(store: UsageStore, settings: SettingsStore, notifications: NotificationManager) {
        self.store = store
        self.settings = settings
        self.notifications = notifications
        self.observeStoreChanges()
        self.observeSettingsChanges()
    }

    var selectedProvider: UsageProvider {
        settings.selectedProvider
    }

    private var currentSnapshot: UsageSnapshot? {
        store.snapshots[settings.selectedProvider]
    }

    private var currentError: String? {
        store.errors[settings.selectedProvider]
    }

    var sessionText: String {
        guard let snapshot = currentSnapshot else { return "--" }
        if let percent = snapshot.sessionUsedPercent {
            return String(format: "%.0f%%", percent)
        }
        return "--"
    }

    var weeklyText: String {
        guard let snapshot = currentSnapshot else { return "--" }
        if let percent = snapshot.weeklyUsedPercent {
            return String(format: "%.0f%%", percent)
        }
        return "--"
    }

    var displayPercentText: String {
        guard let percent = currentSnapshot?.sessionUsedPercent else { return "--" }
        return String(format: "%.0f%%", percent)
    }

    var sessionProgress: Double? {
        guard let percent = currentSnapshot?.sessionUsedPercent else { return nil }
        return max(0, min(1, percent / 100.0))
    }

    var weeklyProgress: Double? {
        guard let percent = currentSnapshot?.weeklyUsedPercent else { return nil }
        return max(0, min(1, percent / 100.0))
    }

    var sessionPercentValue: Double? {
        currentSnapshot?.sessionUsedPercent
    }

    var weeklyPercentValue: Double? {
        currentSnapshot?.weeklyUsedPercent
    }

    var sessionDetailText: String? {
        guard let snapshot = currentSnapshot,
              let used = snapshot.sessionUsedPercent,
              let limit = snapshot.sessionLimitValue
        else { return nil }
        guard limit > 1_000 else { return nil }
        return UsageFormatter.formatAbsolute(usedPercent: used, limit: limit)
    }

    var weeklyDetailText: String? {
        guard let snapshot = currentSnapshot,
              let used = snapshot.weeklyUsedPercent,
              let limit = snapshot.weeklyLimitValue
        else { return nil }
        guard limit > 1_000 else { return nil }
        return UsageFormatter.formatAbsolute(usedPercent: used, limit: limit)
    }

    var sessionResetText: String {
        guard let snapshot = currentSnapshot else { return "" }
        return formatReset(prefix: "Session", date: snapshot.sessionResetAt)
    }

    var weeklyResetText: String {
        guard let snapshot = currentSnapshot else { return "" }
        return formatReset(prefix: "Weekly", date: snapshot.weeklyResetAt)
    }

    private func formatReset(prefix: String, date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        let remaining = max(0, date.timeIntervalSinceNow)
        let text = formatter.string(from: remaining) ?? ""
        return text.isEmpty ? "" : "\(prefix) resets in \(text)"
    }

    var errorText: String? {
        currentError
    }

    var isAuthError: Bool {
        guard let err = currentError else { return false }
        let lower = err.lowercased()
        return lower.contains("token expired")
            || lower.contains("re-authenticate")
            || lower.contains("unauthorized")
            || lower.contains("credentials not found")
            || lower.contains("log in")
    }

    var errorHint: String? {
        guard currentError != nil, isAuthError else { return nil }
        if store.selectedProvider == .claude {
            return "Run `claude` in Terminal to re-authenticate."
        }
        return "Run `codex` in Terminal to re-authenticate."
    }

    var hasErrorState: Bool {
        currentSnapshot == nil && currentError != nil
    }

    var staleText: String? {
        guard store.isStale, let updated = currentSnapshot?.sourceMtime else { return nil }
        let minutes = Int(Date().timeIntervalSince(updated) / 60)
        if minutes <= 1 { return "Last updated 1m ago" }
        return "Last updated \(minutes)m ago"
    }

    func refreshNow() {
        Task { [weak self] in
            guard let self else { return }
            await self.store.refresh(provider: self.settings.selectedProvider)
        }
    }

    private func observeStoreChanges() {
        observeChanges {
            _ = self.store.snapshots
            _ = self.store.errors
            _ = self.store.selectedProvider
        } onChange: { [weak self] in
            guard let self else { return }
            self.handleStoreChange()
            self.observeStoreChanges()
        }
    }

    private func handleStoreChange() {
        let provider = store.selectedProvider
        guard let snapshot = currentSnapshot else { return }

        let sessionPercent = snapshot.sessionUsedPercent
        let weeklyPercent = snapshot.weeklyUsedPercent

        var sessionGate = sessionThresholdGates[provider] ?? ThresholdGate()
        let sessionThreshold = sessionPercent.map { percent in
            sessionGate.nextThreshold(
                usedPercent: Int(percent.rounded(.down)),
                resetAt: snapshot.sessionResetAt)
        } ?? nil
        sessionThresholdGates[provider] = sessionGate

        var weeklyGate = weeklyThresholdGates[provider] ?? ThresholdGate()
        let weeklyThreshold = weeklyPercent.map { percent in
            weeklyGate.nextThreshold(
                usedPercent: Int(percent.rounded(.down)),
                resetAt: snapshot.weeklyResetAt)
        } ?? nil
        weeklyThresholdGates[provider] = weeklyGate

        let chosenThreshold = max(sessionThreshold ?? 0, weeklyThreshold ?? 0)
        guard chosenThreshold > 0 else { return }
        guard settings.isThresholdEnabled(chosenThreshold) else { return }

        let isWeekly = (weeklyThreshold ?? 0) > (sessionThreshold ?? 0)
        let scope = isWeekly ? "Weekly" : "Session"

        let providerTitle = provider == .claude ? "Claude Code" : "Codex"
        let body = notificationBody(scope: scope, threshold: chosenThreshold)

        notifications.postThresholdAlert(title: providerTitle, body: body)
    }

    private func notificationBody(scope: String, threshold: Int) -> String {
        switch threshold {
        case UsageThresholds.warning60:
            return "\(scope) usage at 60%"
        case UsageThresholds.warning80:
            return "\(scope) usage at 80%. Consider pacing."
        case UsageThresholds.critical90:
            return "\(scope) limit approaching. 10% remaining."
        default:
            return "\(scope) usage at \(threshold)%"
        }
    }

    private func observeSettingsChanges() {
        observeChanges {
            _ = self.settings.pollInterval
            _ = self.settings.selectedProvider
        } onChange: { [weak self] in
            guard let self else { return }
            self.store.updatePollInterval(self.settings.pollInterval.seconds)
            self.store.updateSelectedProvider(self.settings.selectedProvider)
            self.refreshNow()
            self.observeSettingsChanges()
        }
    }

    func isSelected(_ provider: UsageProvider) -> Bool {
        settings.selectedProvider == provider
    }

    func selectProvider(_ provider: UsageProvider) {
        settings.selectedProvider = provider
    }
}

enum UsageFormatter {
    static func formatAbsolute(usedPercent: Double, limit: Double) -> String {
        let used = (usedPercent / 100.0) * limit
        return "\(formatNumber(used)) of \(formatNumber(limit)) tokens"
    }

    private static func formatNumber(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}
