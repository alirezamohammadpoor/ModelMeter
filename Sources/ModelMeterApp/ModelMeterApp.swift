import ModelMeterCore
import SwiftUI

@main
struct ModelMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: UsageStore
    @State private var settings: SettingsStore
    @State private var viewModel: MenuViewModel
    @State private var notifications: NotificationManager
    @State private var updateCoordinator: UpdateCoordinator

    init() {
        FontRegistrar.registerBundledFonts()
        let settings = SettingsStore()
        let store = UsageStore(pollInterval: settings.pollInterval.seconds)
        let notifications = NotificationManager()
        let viewModel = MenuViewModel(store: store, settings: settings, notifications: notifications)
        let sparkleUpdater = SparkleUpdateService()
        let updateCoordinator = UpdateCoordinator(
            releaseService: GitHubReleaseService(),
            sparkleUpdater: sparkleUpdater,
            releasePageOpener: ReleasePageOpener()
        )
        _store = State(wrappedValue: store)
        _settings = State(wrappedValue: settings)
        _notifications = State(wrappedValue: notifications)
        _viewModel = State(wrappedValue: viewModel)
        _updateCoordinator = State(wrappedValue: updateCoordinator)
        appDelegate.configure(store: store, viewModel: viewModel, notifications: notifications)
    }

    var body: some Scene {
        Settings {
            SettingsView(store: store, settings: settings, updateCoordinator: updateCoordinator)
        }
    }
}
