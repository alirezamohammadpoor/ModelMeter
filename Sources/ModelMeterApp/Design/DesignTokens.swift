import SwiftUI

enum VercelColors {
    static func background100(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF)
    }

    static func background200(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0A0A0A) : Color(hex: 0xFAFAFA)
    }

    static func background300(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x111111) : Color(hex: 0xF5F5F5)
    }

    static func accents1(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x111111) : Color(hex: 0xFAFAFA)
    }

    static func accents2(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1A1A1A) : Color(hex: 0xEAEAEA)
    }

    static func accents3(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x333333) : Color(hex: 0x999999)
    }

    static func accents4(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x666666) : Color(hex: 0x888888)
    }

    static func accents5(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x888888) : Color(hex: 0x666666)
    }

    static func foreground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xFFFFFF) : Color(hex: 0x000000)
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x333333) : Color(hex: 0xEAEAEA)
    }

    static func borderHover(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x444444) : Color(hex: 0xCFCFCF)
    }

    static let success = Color(hex: 0x50E3C2)
    static let warning = Color(hex: 0xF5A623)
    static let error = Color(hex: 0xEE0000)
    static let highlightPurple = Color(hex: 0x7928CA)
}

enum VercelStatusColor {
    case normal
    case warning
    case critical

    static func forUsagePercent(_ percent: Double) -> VercelStatusColor {
        switch percent {
        case 95...:
            return .critical
        case 60...:
            return .warning
        default:
            return .normal
        }
    }

    func color(_ scheme: ColorScheme) -> Color {
        switch self {
        case .normal:
            return VercelColors.foreground(scheme)
        case .warning:
            return VercelColors.warning
        case .critical:
            return VercelColors.error
        }
    }
}
