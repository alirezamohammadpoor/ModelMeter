import AppKit
import ModelMeterCore

enum StatusIconRenderer {
    private static let claudeStatusIconSize = NSSize(width: 14, height: 14)
    private static let codexStatusIconSize = NSSize(width: 16, height: 16)

    struct RenderedStatusItem {
        let image: NSImage?
        let title: NSAttributedString
        let symbolColor: NSColor
    }

    static func render(
        provider: UsageProvider,
        sessionPercent: Double?,
        weeklyPercent: Double?
    ) -> RenderedStatusItem {
        let displayedPercent = sessionPercent ?? weeklyPercent ?? 0
        let isCritical = displayedPercent >= Double(UsageThresholds.critical90)

        let text: String
        if let sessionPercent {
            text = String(format: "%.0f%%", sessionPercent)
        } else {
            text = "--"
        }

        let textColor = isCritical ? NSColor(hex: 0xBF4D43) : .white
        let title = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: textColor,
                .font: NSFont.systemFont(ofSize: 12, weight: .medium)
            ])

        let symbolName = provider == .claude ? "sparkles" : "circle.grid.2x2.fill"
        let image = ProviderLogoAssets.image(for: provider)
            ?? NSImage(systemSymbolName: symbolName, accessibilityDescription: provider.displayName)?
                .withSymbolConfiguration(.init(pointSize: 11, weight: .medium))
        let targetSize = provider == .codex ? codexStatusIconSize : claudeStatusIconSize
        let normalizedImage = image?.normalizedForStatusBar(size: targetSize)
        let tintedImage = normalizedImage?.tinted(with: .white)
        tintedImage?.isTemplate = false

        return RenderedStatusItem(image: tintedImage, title: title, symbolColor: .white)
    }
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

private extension NSImage {
    func normalizedForStatusBar(size: NSSize) -> NSImage {
        let output = NSImage(size: size)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let source = NSRect(origin: .zero, size: self.size)
        let ratio = min(size.width / self.size.width, size.height / self.size.height)
        let drawSize = NSSize(width: self.size.width * ratio, height: self.size.height * ratio)
        let drawRect = NSRect(
            x: (size.width - drawSize.width) / 2,
            y: (size.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height)
        draw(in: drawRect, from: source, operation: .sourceOver, fraction: 1.0)
        output.unlockFocus()
        output.isTemplate = self.isTemplate
        return output
    }

    func tinted(with color: NSColor) -> NSImage {
        let output = copy() as? NSImage ?? NSImage(size: size)
        output.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: output.size)
        rect.fill(using: .sourceAtop)
        output.unlockFocus()
        return output
    }
}
