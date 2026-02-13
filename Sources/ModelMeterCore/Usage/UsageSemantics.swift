import Foundation

public enum UsageThresholds {
    public static let warning60 = 60
    public static let warning80 = 80
    public static let critical90 = 90
    public static let all = [warning60, warning80, critical90]
}

public enum UsageStatusSemantics: Sendable {
    case normal
    case warning
    case critical

    public static func fromPercent(_ percent: Double) -> UsageStatusSemantics {
        switch percent {
        case Double(UsageThresholds.critical90)...:
            return .critical
        case Double(UsageThresholds.warning60)...:
            return .warning
        default:
            return .normal
        }
    }
}
