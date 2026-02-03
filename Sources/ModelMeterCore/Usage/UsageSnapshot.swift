import Foundation

public struct UsagePercentLimitConfig: Sendable, Codable {
    public let sessionLimitPercent: Double
    public let weeklyLimitPercent: Double

    public init(sessionLimitPercent: Double, weeklyLimitPercent: Double) {
        self.sessionLimitPercent = sessionLimitPercent
        self.weeklyLimitPercent = weeklyLimitPercent
    }

    public static let `default` = UsagePercentLimitConfig(sessionLimitPercent: 100, weeklyLimitPercent: 100)
}

public struct UsageSnapshot: Sendable {
    public let sessionUsed: Double
    public let weeklyUsed: Double
    public let sessionLimit: Double?
    public let weeklyLimit: Double?
    public let sessionUsedPercent: Double?
    public let weeklyUsedPercent: Double?
    public let sessionResetAt: Date?
    public let weeklyResetAt: Date?
    public let updatedAt: Date
    public let sourcePath: URL
    public let sourceMtime: Date

    public var sessionLimitValue: Double? {
        guard let sessionLimit, sessionLimit > 0 else { return nil }
        return sessionLimit
    }

    public var weeklyLimitValue: Double? {
        guard let weeklyLimit, weeklyLimit > 0 else { return nil }
        return weeklyLimit
    }

    public init(
        sessionUsed: Double,
        weeklyUsed: Double,
        sessionLimit: Double?,
        weeklyLimit: Double?,
        sessionUsedPercent: Double?,
        weeklyUsedPercent: Double?,
        sessionResetAt: Date?,
        weeklyResetAt: Date?,
        updatedAt: Date,
        sourcePath: URL,
        sourceMtime: Date
    ) {
        self.sessionUsed = sessionUsed
        self.weeklyUsed = weeklyUsed
        self.sessionLimit = sessionLimit
        self.weeklyLimit = weeklyLimit
        self.sessionUsedPercent = sessionUsedPercent
        self.weeklyUsedPercent = weeklyUsedPercent
        self.sessionResetAt = sessionResetAt
        self.weeklyResetAt = weeklyResetAt
        self.updatedAt = updatedAt
        self.sourcePath = sourcePath
        self.sourceMtime = sourceMtime
    }
}
