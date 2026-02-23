import Foundation
import Observation
import os.log

private let storeLogger = Logger(subsystem: "com.modelmeter", category: "UsageStore")
private let storeDebug = ProcessInfo.processInfo.environment["MODELMETER_DEBUG"] == "1"

@MainActor
@Observable
public final class UsageStore {
    public private(set) var snapshots: [UsageProvider: UsageSnapshot] = [:]
    public private(set) var errors: [UsageProvider: String] = [:]
    public private(set) var lastRefreshByProvider: [UsageProvider: Date] = [:]
    public private(set) var selectedProvider: UsageProvider = .claude

    public var pollInterval: TimeInterval
    public var staleAfter: TimeInterval

    private let refreshActor: UsageRefreshActor
    private var timerTask: Task<Void, Never>?
    private var refreshingProviders: Set<UsageProvider> = []

    public init(
        pollInterval: TimeInterval = 30,
        staleAfter: TimeInterval = 300,
        connector: UsageProviderConnector = LocalCLICredentialsConnector()
    ) {
        self.pollInterval = pollInterval
        self.staleAfter = staleAfter
        self.refreshActor = UsageRefreshActor(connector: connector)
    }

    public var isStale: Bool {
        guard let snapshot = snapshots[selectedProvider] else { return false }
        return Date().timeIntervalSince(snapshot.sourceMtime) > staleAfter
    }

    public func start() {
        startTimer()
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
        await refresh(provider: selectedProvider)
    }

    public func refresh(provider: UsageProvider) async {
        guard !refreshingProviders.contains(provider) else { return }
        refreshingProviders.insert(provider)
        defer { refreshingProviders.remove(provider) }

        do {
            let snapshot = try await refreshActor.refresh(provider: provider)
            snapshots[provider] = snapshot
            errors[provider] = nil
            lastRefreshByProvider[provider] = Date()
            if storeDebug {
                storeLogger.debug("[ModelMeter] UsageStore.refresh(\(String(describing: provider))): session=\(snapshot.sessionUsedPercent ?? -1)%, weekly=\(snapshot.weeklyUsedPercent ?? -1)%")
            }
        } catch {
            errors[provider] = error.localizedDescription
            snapshots[provider] = nil
            lastRefreshByProvider[provider] = Date()
            if storeDebug {
                storeLogger.debug("[ModelMeter] UsageStore.refresh(\(String(describing: provider))): error = \(error.localizedDescription)")
            }
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        guard pollInterval > 0 else { return }

        timerTask = Task(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                let sleepSeconds = self?.pollInterval ?? 30
                try? await Task.sleep(for: .seconds(sleepSeconds))
                if Task.isCancelled { return }
                await self?.refresh()
            }
        }
    }
}
