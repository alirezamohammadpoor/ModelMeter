import AppKit
import Sparkle

@MainActor
final class SparkleUpdateService: NSObject, SparkleUpdating {
    private let updaterController: SPUStandardUpdaterController?

    override init() {
        if FeatureFlags.useSparkleUpdater {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: false,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }
        super.init()
    }

    func checkForUpdates() throws {
        guard let updater = updaterController?.updater else {
            throw NSError(
                domain: "SparkleUpdateService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Sparkle updater is not available."]
            )
        }
        updater.checkForUpdates()
    }

    func checkForUpdatesInBackground() throws {
        guard let updater = updaterController?.updater else {
            throw NSError(
                domain: "SparkleUpdateService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Sparkle updater is not available."]
            )
        }
        updater.checkForUpdatesInBackground()
    }
}
