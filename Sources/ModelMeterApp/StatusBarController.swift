import AppKit
import SwiftUI
import Observation
import ModelMeterCore

private class PopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var panel: PopoverPanel?
    private var globalMonitor: Any?
    private var lastCloseTime: Date?
    private let viewModel: MenuViewModel

    init(viewModel: MenuViewModel) {
        self.viewModel = viewModel
        super.init()
        let button = statusItem.button
        button?.imagePosition = .imageLeft
        button?.appearance = NSAppearance(named: .darkAqua)
        button?.target = self
        button?.action = #selector(togglePopover)

        observeStatusChanges()
        updateStatusIcon()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if let t = lastCloseTime, Date().timeIntervalSince(t) < 0.3 {
            lastCloseTime = nil
            return
        }

        if let panel = panel, panel.isVisible {
            closePanel()
        } else {
            showPanel(relativeTo: button)
        }
    }

    private func showPanel(relativeTo button: NSStatusBarButton) {
        let hostingView = NSHostingView(rootView: MenuView(viewModel: viewModel))
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = PopoverPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar + 1
        panel.hasShadow = true
        panel.contentView = hostingView

        guard let buttonWindow = button.window else { return }
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let size = hostingView.fittingSize
        let x = screenRect.midX - size.width / 2
        let y = screenRect.minY - size.height - 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePanel()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }

    @objc private func panelDidResignKey() {
        closePanel()
    }

    private func closePanel() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
        panel?.orderOut(nil)
        panel = nil
        lastCloseTime = Date()
    }

    private func observeStatusChanges() {
        withObservationTracking {
            _ = viewModel.sessionPercentValue
            _ = viewModel.weeklyPercentValue
            _ = viewModel.selectedProvider
        } onChange: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.updateStatusIcon()
                self.observeStatusChanges()
            }
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let session = viewModel.sessionPercentValue
        let weekly = viewModel.weeklyPercentValue
        let rendered = StatusIconRenderer.render(
            provider: viewModel.selectedProvider,
            sessionPercent: session,
            weeklyPercent: weekly)

        button.image = rendered.image
        button.image?.isTemplate = false
        button.contentTintColor = nil
        button.attributedTitle = rendered.title

        let eitherCritical = (session ?? 0) >= Double(UsageThresholds.critical90)
            || (weekly ?? 0) >= Double(UsageThresholds.critical90)
        if eitherCritical {
            addPulseAnimationIfNeeded(to: button)
        } else {
            removePulseAnimation(from: button)
        }
    }

    private func addPulseAnimationIfNeeded(to button: NSStatusBarButton) {
        let key = "pulseOpacity"
        if button.layer?.animation(forKey: key) != nil { return }
        button.wantsLayer = true
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.7
        animation.toValue = 1.0
        animation.duration = 2.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        button.layer?.add(animation, forKey: key)
    }

    private func removePulseAnimation(from button: NSStatusBarButton) {
        button.layer?.removeAnimation(forKey: "pulseOpacity")
    }
}
