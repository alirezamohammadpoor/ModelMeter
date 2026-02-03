import AppKit
import ModelMeterCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private weak var store: UsageStore?
    private weak var viewModel: MenuViewModel?
    private weak var notifications: NotificationManager?

    func configure(store: UsageStore, viewModel: MenuViewModel, notifications: NotificationManager) {
        self.store = store
        self.viewModel = viewModel
        self.notifications = notifications
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let viewModel {
            statusBarController = StatusBarController(viewModel: viewModel)
        }
        migrateOldConfig()
        ensureDefaultConfig()
        Task { [weak self] in
            await self?.notifications?.requestAuthorization()
        }
        store?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.stop()
    }

    private func ensureDefaultConfig() {
        let configStore = ConfigStore()
        let fileManager = FileManager.default
        let scriptsRoot = Bundle.main.resourceURL?.appendingPathComponent("ModelMeterScripts")
        let claudePath = scriptsRoot?.appendingPathComponent("claude_usage.py").path
        let codexPath = scriptsRoot?.appendingPathComponent("codex_usage.py").path

        let bundledClaude = (claudePath.flatMap { fileManager.fileExists(atPath: $0) } == true) ? claudePath : nil
        let bundledCodex = (codexPath.flatMap { fileManager.fileExists(atPath: $0) } == true) ? codexPath : nil

        if let existing = try? configStore.load() {
            var updated = existing
            var didChange = false

            if updated.claudeCommand?.isEmpty ?? true,
               let bundledClaude {
                updated.claudeCommand = bundledClaude
                didChange = true
            }

            if updated.codexCommand?.isEmpty ?? true,
               let bundledCodex {
                updated.codexCommand = bundledCodex
                didChange = true
            }

            if let claudeCommand = updated.claudeCommand,
               (!fileManager.fileExists(atPath: claudeCommand) || shouldReplaceBundled(command: claudeCommand)),
               let bundledClaude {
                updated.claudeCommand = bundledClaude
                didChange = true
            }

            if let codexCommand = updated.codexCommand,
               (!fileManager.fileExists(atPath: codexCommand) || shouldReplaceBundled(command: codexCommand)),
               let bundledCodex {
                updated.codexCommand = bundledCodex
                didChange = true
            }

            if didChange {
                do {
                    try configStore.save(updated)
                } catch {
                    NSLog("Failed to repair config: %@", error.localizedDescription)
                }
            }
            return
        }

        var config = ModelMeterConfig(source: "command")
        config.claudeCommand = bundledClaude
        config.codexCommand = bundledCodex

        do {
            try configStore.save(config)
        } catch {
            NSLog("Failed to write default config: %@", error.localizedDescription)
        }
    }

    private func migrateOldConfig() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let newDir = home.appendingPathComponent(".modelmeter", isDirectory: true)
        let newConfig = newDir.appendingPathComponent("config.json")
        let oldConfig = home.appendingPathComponent(".menuusage", isDirectory: true)
            .appendingPathComponent("config.json")

        guard !fileManager.fileExists(atPath: newConfig.path),
              fileManager.fileExists(atPath: oldConfig.path) else { return }

        do {
            if !fileManager.fileExists(atPath: newDir.path) {
                try fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
            }
            try fileManager.copyItem(at: oldConfig, to: newConfig)
        } catch {
            NSLog("Failed to migrate old config: %@", error.localizedDescription)
        }
    }

    private func shouldReplaceBundled(command: String) -> Bool {
        let normalized = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOldBundled = normalized.contains(".app/Contents/Resources/MenuUsageScripts")
        let isNewBundled = normalized.contains(".app/Contents/Resources/ModelMeterScripts")
        guard isOldBundled || isNewBundled else { return false }
        let bundlePath = Bundle.main.bundleURL.path
        return isOldBundled || !normalized.hasPrefix(bundlePath)
    }
}
