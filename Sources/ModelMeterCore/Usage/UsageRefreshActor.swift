import Foundation

public actor UsageRefreshActor {
    private let connector: UsageProviderConnector

    public init(connector: UsageProviderConnector) {
        self.connector = connector
    }

    public func refresh(provider: UsageProvider) async throws -> UsageSnapshot {
        try await connector.fetchUsage(for: provider)
    }
}
