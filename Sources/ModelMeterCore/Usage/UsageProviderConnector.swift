import Foundation

public enum AuthMode: String, Sendable {
    case localCLI = "local-cli"
}

public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let message: String?

    public init(isValid: Bool, message: String? = nil) {
        self.isValid = isValid
        self.message = message
    }

    public static let valid = ValidationResult(isValid: true)
}

public protocol UsageProviderConnector: Sendable {
    var authMode: AuthMode { get }
    func fetchUsage(for provider: UsageProvider) async throws -> UsageSnapshot
    func validateEnvironment(for provider: UsageProvider) -> ValidationResult
}
