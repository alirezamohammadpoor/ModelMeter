import XCTest
@testable import ModelMeterCore

final class UsageStoreTests: XCTestCase {
    func testProviderRefreshesCanRunIndependently() async {
        let connector = MockConnector(delayNanoseconds: 80_000_000)
        let store = await MainActor.run {
            UsageStore(pollInterval: 300, connector: connector)
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await store.refresh(provider: .claude) }
            group.addTask { await store.refresh(provider: .codex) }
        }

        let counts = await connector.counts()
        XCTAssertEqual(counts[.claude], 1)
        XCTAssertEqual(counts[.codex], 1)
    }

    func testDuplicateProviderRefreshIsCoalesced() async {
        let connector = MockConnector(delayNanoseconds: 120_000_000)
        let store = await MainActor.run {
            UsageStore(pollInterval: 300, connector: connector)
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await store.refresh(provider: .claude) }
            group.addTask { await store.refresh(provider: .claude) }
        }

        let counts = await connector.counts()
        XCTAssertEqual(counts[.claude], 1)
    }

    func testStopPreventsPostCancelTimerTick() async throws {
        let connector = MockConnector(delayNanoseconds: 1_000_000)
        let store = await MainActor.run {
            UsageStore(pollInterval: 0.05, connector: connector)
        }

        await MainActor.run {
            store.start()
        }
        try await Task.sleep(nanoseconds: 15_000_000)
        await MainActor.run {
            store.stop()
        }
        let before = await connector.totalCount()
        try await Task.sleep(nanoseconds: 80_000_000)
        let after = await connector.totalCount()

        XCTAssertEqual(after, before)
    }
}

private actor MockConnector: UsageProviderConnector {
    nonisolated let authMode: AuthMode = .localCLI

    private var callCounts: [UsageProvider: Int] = [:]
    private let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchUsage(for provider: UsageProvider) async throws -> UsageSnapshot {
        callCounts[provider, default: 0] += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        let now = Date()
        return UsageSnapshot(
            sessionUsed: 10,
            weeklyUsed: 20,
            sessionLimit: 100,
            weeklyLimit: 100,
            sessionUsedPercent: 10,
            weeklyUsedPercent: 20,
            sessionResetAt: now.addingTimeInterval(3600),
            weeklyResetAt: now.addingTimeInterval(7200),
            updatedAt: now,
            sourcePath: URL(fileURLWithPath: "/tmp/mock"),
            sourceMtime: now
        )
    }

    nonisolated func validateEnvironment(for provider: UsageProvider) -> ValidationResult {
        .valid
    }

    func counts() -> [UsageProvider: Int] {
        callCounts
    }

    func totalCount() -> Int {
        callCounts.values.reduce(0, +)
    }
}
