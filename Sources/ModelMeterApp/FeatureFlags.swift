import Foundation

enum FeatureFlags {
    static let useSparkleUpdater: Bool = {
        return ProcessInfo.processInfo.environment["USE_SPARKLE_UPDATER"] != "0"
    }()
}

enum AppConstants {
    static let fallbackVersion = "1.0.0"
}
