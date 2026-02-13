import SwiftUI
import ModelMeterCore

enum ModelMeterColors {
    // Claude / Anthropic
    static let claudeAccent = Color(hex: 0xCC785C)      // Book Cloth
    static let claudeSecondary = Color(hex: 0xD4A27F)   // Kraft
    static let claudeCloudLight = Color(hex: 0xBFBFBA)  // Cloud Light
    static let claudeSubtle = Color(hex: 0xEBDBBC)      // Manilla
    static let claudeText = Color(hex: 0xFAFAF7)        // Ivory Light
    static let claudeContainer = Color(hex: 0x262625)   // Slate Medium
    static let claudeSlateLight = Color(hex: 0x40403E)  // Slate Light (segmented container)
    static let claudeContainerHover = Color(hex: 0x3A3A39)
    static let claudeError = Color(hex: 0xBF4D43)

    // Codex / OpenAI
    static let codexPrimary = Color.white
    static let codexSecondary = Color.white.opacity(0.60)
    static let codexContainer = Color.white.opacity(0.15)
    static let codexTrack = Color.white.opacity(0.20)
    static let codexBackground = Color.black
}

enum ProviderTheme {
    static func accent(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeAccent
        case .codex: return ModelMeterColors.codexPrimary
        }
    }

    static func primaryText(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeText
        case .codex: return ModelMeterColors.codexPrimary
        }
    }

    static func secondaryText(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeCloudLight
        case .codex: return ModelMeterColors.codexSecondary
        }
    }

    static func subtleContainer(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeSubtle.opacity(0.20)
        case .codex: return ModelMeterColors.codexContainer
        }
    }

    static func hoverContainer(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeContainerHover
        case .codex: return ModelMeterColors.codexContainer
        }
    }

    static func controlBackground(_ provider: UsageProvider) -> Color {
        Color.clear
    }

    static func progressTrack(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeAccent.opacity(0.20)
        case .codex: return ModelMeterColors.codexTrack
        }
    }

    static func progressFill(_ provider: UsageProvider, percent: Double?) -> Color {
        guard let percent else { return accent(provider) }
        if provider == .claude, percent >= Double(UsageThresholds.critical90) {
            return ModelMeterColors.claudeError
        }
        return accent(provider)
    }

    static func statusColor(_ provider: UsageProvider, percent: Double?) -> Color {
        guard let percent else { return secondaryText(provider) }
        if provider == .claude, percent >= Double(UsageThresholds.critical90) {
            return ModelMeterColors.claudeError
        }
        return accent(provider)
    }

    static func border(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeSecondary.opacity(0.30)
        case .codex: return Color.white.opacity(0.25)
        }
    }

    static func segmentedContainer(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeSlateLight
        case .codex: return Color.black
        }
    }

    static func segmentedBorder(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeCloudLight.opacity(0.18)
        case .codex: return Color.white.opacity(0.20)
        }
    }

    static func segmentedActiveBackground(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeContainer
        case .codex: return Color.white.opacity(0.15)
        }
    }

    static func segmentedInactiveText(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeCloudLight
        case .codex: return Color.white.opacity(0.50)
        }
    }

    static func segmentedActiveText(_ provider: UsageProvider) -> Color {
        switch provider {
        case .claude: return ModelMeterColors.claudeText
        case .codex: return Color.white
        }
    }
}

enum ModelMeterMotion {
    static let themeSwitch = Animation.easeOut(duration: 0.15)
    static let progressChange = Animation.easeOut(duration: 0.30)
    static let hover = Animation.easeOut(duration: 0.10)
}

enum ModelMeterLayout {
    static let popoverWidth: CGFloat = 280
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    static let sectionGap: CGFloat = 16
    static let elementGap: CGFloat = 8
    static let progressHeight: CGFloat = 4
    static let progressRadius: CGFloat = 2
}
