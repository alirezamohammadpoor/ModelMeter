import Foundation
import Observation

@MainActor
@Observable
public final class UsageStore {
    public private(set) var snapshots: [UsageProvider: UsageSnapshot] = [:]
    public private(set) var errors: [UsageProvider: String] = [:]
    public private(set) var isRefreshing: Bool = false
    public private(set) var lastRefreshByProvider: [UsageProvider: Date] = [:]
    public private(set) var selectedProvider: UsageProvider = .claude

    public var pollInterval: TimeInterval
    public var staleAfter: TimeInterval

    private let parser: UsageParser
    private let commandSource: CommandUsageSource
    private let configStore: ConfigStore
    private var timerTask: Task<Void, Never>?

    public init(
        pollInterval: TimeInterval = 30,
        staleAfter: TimeInterval = 300,
        parser: UsageParser = UsageParser(),
        commandSource: CommandUsageSource = CommandUsageSource(),
        configStore: ConfigStore = ConfigStore()
    ) {
        self.pollInterval = pollInterval
        self.staleAfter = staleAfter
        self.parser = parser
        self.commandSource = commandSource
        self.configStore = configStore
    }

    public var isStale: Bool {
        guard let snapshot = self.snapshots[self.selectedProvider] else { return false }
        return Date().timeIntervalSince(snapshot.sourceMtime) > staleAfter
    }

    public func start() {
        self.startTimer()
        Task { [weak self] in
            await self?.refresh()
        }
    }

    public func updatePollInterval(_ interval: TimeInterval) {
        guard interval > 0 else { return }
        pollInterval = interval
        startTimer()
    }

    public func updateSelectedProvider(_ provider: UsageProvider) {
        selectedProvider = provider
    }

    public func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let config = try configStore.load()
            let source = (config?.source ?? "command").lowercased()
            if source == "command" {
                let parsed = try commandSource.fetch(config: config ?? ModelMeterConfig(), provider: selectedProvider)
                snapshots[selectedProvider] = parsed
                errors[selectedProvider] = nil
                lastRefreshByProvider[selectedProvider] = Date()
                print("Usage snapshot: session=\(parsed.sessionUsed) weekly=\(parsed.weeklyUsed) source=command provider=\(selectedProvider.rawValue)")
            } else {
                let limits = UsagePercentLimitConfig(
                    sessionLimitPercent: config?.sessionLimitPercent ?? UsagePercentLimitConfig.default.sessionLimitPercent,
                    weeklyLimitPercent: config?.weeklyLimitPercent ?? UsagePercentLimitConfig.default.weeklyLimitPercent
                )
                guard let located = UsageFileLocator.locate(overridePath: config?.usageFilePath) else {
                    errors[selectedProvider] = "No usage file found."
                    snapshots[selectedProvider] = nil
                    lastRefreshByProvider[selectedProvider] = Date()
                    return
                }

                let data = try Data(contentsOf: located.url)
                let attrs = try FileManager.default.attributesOfItem(atPath: located.url.path)
                let mtime = (attrs[.modificationDate] as? Date) ?? Date()
                let parsed = try parser.parse(data: data, sourceURL: located.url, sourceMtime: mtime, limits: limits)

                snapshots[selectedProvider] = parsed
                errors[selectedProvider] = nil
                lastRefreshByProvider[selectedProvider] = Date()
                print("Usage snapshot: session=\(parsed.sessionUsed) weekly=\(parsed.weeklyUsed) source=\(located.source)")
            }
        } catch {
            errors[selectedProvider] = error.localizedDescription
            snapshots[selectedProvider] = nil
            lastRefreshByProvider[selectedProvider] = Date()
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        guard pollInterval > 0 else { return }
        timerTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.pollInterval ?? 30))
                await self?.refresh()
            }
        }
    }

    deinit {}
}
