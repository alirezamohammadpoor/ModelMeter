import Foundation

public enum UsageParserError: LocalizedError {
    case unsupportedFormat
    case missingDailyData
    case invalidDate

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported usage file format."
        case .missingDailyData:
            return "No daily usage entries found."
        case .invalidDate:
            return "Invalid date in usage file."
        }
    }
}

public struct UsageParser: Sendable {
    public init() {}

    public func parse(
        data: Data,
        sourceURL: URL,
        sourceMtime: Date,
        limits: UsagePercentLimitConfig
    ) throws -> UsageSnapshot {
        let decoder = JSONDecoder()
        let stats = try decoder.decode(StatsCache.self, from: data)

        let totals = Self.dailyTotals(from: stats)
        guard !totals.isEmpty else {
            throw UsageParserError.missingDailyData
        }

        let sorted = totals.sorted { $0.date < $1.date }
        guard let latest = sorted.last else {
            throw UsageParserError.missingDailyData
        }

        let calendar = Calendar.current
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: latest.date) else {
            throw UsageParserError.invalidDate
        }
        let weeklyTotal = sorted
            .filter { $0.date >= weekStart }
            .reduce(0.0) { $0 + $1.total }

        let sessionLimit = limits.sessionLimitPercent > 0 ? limits.sessionLimitPercent : nil
        let weeklyLimit = limits.weeklyLimitPercent > 0 ? limits.weeklyLimitPercent : nil

        let sessionPercent = sessionLimit.map { min(100.0, (latest.total / $0) * 100.0) }
        let weeklyPercent = weeklyLimit.map { min(100.0, (weeklyTotal / $0) * 100.0) }

        let now = Date()
        let sessionReset = ResetSchedule.nextMidnight(after: now)
        let weeklyReset = ResetSchedule.nextWeekStart(after: now)

        return UsageSnapshot(
            sessionUsed: latest.total,
            weeklyUsed: weeklyTotal,
            sessionLimit: sessionLimit,
            weeklyLimit: weeklyLimit,
            sessionUsedPercent: sessionPercent,
            weeklyUsedPercent: weeklyPercent,
            sessionResetAt: sessionReset,
            weeklyResetAt: weeklyReset,
            updatedAt: now,
            sourcePath: sourceURL,
            sourceMtime: sourceMtime
        )
    }

    private static func dailyTotals(from stats: StatsCache) -> [DailyTotal] {
        if let modelTokens = stats.dailyModelTokens, !modelTokens.isEmpty {
            return modelTokens.compactMap { entry in
                guard let date = Self.parseDate(entry.date) else { return nil }
                let total = entry.tokensByModel?.values.reduce(0, +) ?? 0
                return DailyTotal(date: date, total: Double(total))
            }
        }

        if let activity = stats.dailyActivity, !activity.isEmpty {
            return activity.compactMap { entry in
                guard let date = Self.parseDate(entry.date) else { return nil }
                let total = entry.messageCount ?? 0
                return DailyTotal(date: date, total: Double(total))
            }
        }

        return []
    }

    private static func parseDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    // ResetSchedule handles default reset behavior.
}

private struct StatsCache: Decodable {
    let dailyActivity: [DailyActivity]?
    let dailyModelTokens: [DailyModelTokens]?
}

private struct DailyActivity: Decodable {
    let date: String
    let messageCount: Int?
}

private struct DailyModelTokens: Decodable {
    let date: String
    let tokensByModel: [String: Int]?
}

private struct DailyTotal {
    let date: Date
    let total: Double
}
