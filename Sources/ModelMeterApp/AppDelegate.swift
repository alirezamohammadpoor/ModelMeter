import AppKit
import ModelMeterCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    private var statusBarController: StatusBarController?
    private var store: UsageStore?
    private weak var viewModel: MenuViewModel?
    private weak var notifications: NotificationManager?
    private var settingsStore: SettingsStore?
    private var settingsWindow: NSWindow?

    func configure(
        store: UsageStore,
        viewModel: MenuViewModel,
        notifications: NotificationManager,
        settingsStore: SettingsStore
    ) {
        self.store = store
        self.viewModel = viewModel
        self.notifications = notifications
        self.settingsStore = settingsStore
        AppDelegate.shared = self
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
        UpdateManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.stop()
    }

    @objc func openModelMeterSettings(_ sender: Any?) {
        openSettingsWindow()
    }

    func openSettingsWindow() {
        guard let store, let settingsStore else {
            NSLog("openSettingsWindow: store or settingsStore is nil")
            return
        }

        if settingsWindow == nil {
            let settingsView = SettingsView(
                store: store,
                settings: settingsStore
            )
            let hosting = NSHostingController(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "ModelMeter Settings"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentViewController = hosting
            window.delegate = self
            settingsWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.settingsWindow?.orderFrontRegardless()
            self?.settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }

    private func ensureDefaultConfig() {
        let configStore = ConfigStore()
        do {
            try configStore.migrateDeprecatedFields()
        } catch {
            NSLog("Failed to migrate deprecated config fields: %@", error.localizedDescription)
        }

        let fileManager = FileManager.default
        let bundledClaude = bundledScriptPath(fileName: "claude_usage.py")
        let bundledCodex = bundledScriptPath(fileName: "codex_usage.py")

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
        let isLegacyModelMeter = normalized.contains(".app/Contents/Resources/ModelMeterScripts")
        let isSwiftPMBundle = normalized.contains("ModelMeter_ModelMeterApp.bundle")
        guard isOldBundled || isLegacyModelMeter || isSwiftPMBundle else { return false }
        let bundlePath = Bundle.main.bundleURL.path
        return isOldBundled || !normalized.hasPrefix(bundlePath) || !FileManager.default.fileExists(atPath: normalized)
    }

    private func bundledScriptPath(fileName: String) -> String? {
        BundleResourceLocator.bundledScriptPath(fileName: fileName)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        settingsWindow = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let hasVisibleWindows = NSApp.windows.contains {
                $0.isVisible && $0 !== notification.object as? NSWindow
            }
            if !hasVisibleWindows {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
