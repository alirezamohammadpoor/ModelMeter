import Foundation

public struct LocalCLICredentialsConnector: UsageProviderConnector, Sendable {
    public var authMode: AuthMode { .localCLI }

    private let parser: UsageParser
    private let commandSource: CommandUsageSource
    private let configStore: ConfigStore

    public init(
        parser: UsageParser = UsageParser(),
        commandSource: CommandUsageSource = CommandUsageSource(),
        configStore: ConfigStore = ConfigStore()
    ) {
        self.parser = parser
        self.commandSource = commandSource
        self.configStore = configStore
    }

    public func fetchUsage(for provider: UsageProvider) async throws -> UsageSnapshot {
        let config = try configStore.load()
        let source = (config?.source ?? "command").lowercased()

        if source == "command" {
            return try commandSource.fetch(config: config ?? ModelMeterConfig(), provider: provider)
        }

        let limits = UsagePercentLimitConfig(
            sessionLimitPercent: config?.sessionLimitPercent ?? UsagePercentLimitConfig.default.sessionLimitPercent,
            weeklyLimitPercent: config?.weeklyLimitPercent ?? UsagePercentLimitConfig.default.weeklyLimitPercent
        )

        guard let located = UsageFileLocator.locate(overridePath: config?.usageFilePath) else {
            throw CommandUsageError.processFailed("No usage file found.")
        }

        let data = try Data(contentsOf: located.url)
        let attrs = try FileManager.default.attributesOfItem(atPath: located.url.path)
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        return try parser.parse(data: data, sourceURL: located.url, sourceMtime: mtime, limits: limits)
    }

    public func validateEnvironment(for provider: UsageProvider) -> ValidationResult {
        do {
            let config = try configStore.load() ?? ModelMeterConfig(source: "command")
            let command = provider == .claude ? config.claudeCommand : config.codexCommand
            if let command, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .valid
            }
            return ValidationResult(isValid: false, message: "Missing command for \(provider.displayName).")
        } catch {
            return ValidationResult(isValid: false, message: error.localizedDescription)
        }
    }
}
