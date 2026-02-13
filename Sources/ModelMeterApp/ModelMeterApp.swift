import ModelMeterCore
import SwiftUI

@main
struct ModelMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: UsageStore
    @State private var settings: SettingsStore
    @State private var viewModel: MenuViewModel
    @State private var notifications: NotificationManager

    init() {
        FontRegistrar.registerBundledFonts()
        let settings = SettingsStore()
        let store = UsageStore(pollInterval: settings.pollInterval.seconds)
        let notifications = NotificationManager()
        let viewModel = MenuViewModel(store: store, settings: settings, notifications: notifications)
        _store = State(wrappedValue: store)
        _settings = State(wrappedValue: settings)
        _notifications = State(wrappedValue: notifications)
        _viewModel = State(wrappedValue: viewModel)
        appDelegate.configure(
            store: store,
            viewModel: viewModel,
            notifications: notifications,
            settingsStore: settings
        )
    }

    var body: some Scene {
        Settings {
            SettingsView(store: store, settings: settings)
        }
    }
}
