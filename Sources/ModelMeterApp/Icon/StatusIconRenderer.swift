import AppKit

enum StatusIconRenderer {
    struct RenderedIcon {
        let image: NSImage
        let isTemplate: Bool
    }

    enum BarState {
        case normal
        case warning
        case critical

        static func from(percent: Double) -> BarState {
            switch percent {
            case 95...:
                return .critical
            case 60...:
                return .warning
            default:
                return .normal
            }
        }

        var color: NSColor {
            switch self {
            case .normal:
                return NSColor.labelColor
            case .warning:
                return NSColor(calibratedRed: 0xF5 / 255, green: 0xA6 / 255, blue: 0x23 / 255, alpha: 1)
            case .critical:
                return NSColor(calibratedRed: 0xEE / 255, green: 0x00 / 255, blue: 0x00 / 255, alpha: 1)
            }
        }
    }

    private static let trackColor = NSColor(calibratedRed: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255, alpha: 1)

    static func render(sessionPercent: Double, weeklyPercent: Double) -> RenderedIcon {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.isTemplate = false

        let barWidth: CGFloat = 14
        let barHeight: CGFloat = 4
        let gap: CGFloat = 4
        let cornerRadius: CGFloat = 2
        let totalHeight = barHeight + gap + barHeight // 12pt
        let originX = (size.width - barWidth) / 2
        let originY = (size.height - totalHeight) / 2

        let sessionState = BarState.from(percent: sessionPercent)
        let weeklyState = BarState.from(percent: weeklyPercent)
        let bothNormal = sessionState == .normal && weeklyState == .normal

        image.lockFocus()
        defer { image.unlockFocus() }

        // Top bar: session (y is flipped in NSImage — top bar has higher y)
        let topBarY = originY + barHeight + gap
        drawBar(
            x: originX, y: topBarY,
            width: barWidth, height: barHeight,
            cornerRadius: cornerRadius,
            fillPercent: sessionPercent,
            state: sessionState)

        // Bottom bar: weekly
        let bottomBarY = originY
        drawBar(
            x: originX, y: bottomBarY,
            width: barWidth, height: barHeight,
            cornerRadius: cornerRadius,
            fillPercent: weeklyPercent,
            state: weeklyState)

        image.isTemplate = bothNormal
        return RenderedIcon(image: image, isTemplate: bothNormal)
    }

    private static func drawBar(
        x: CGFloat, y: CGFloat,
        width: CGFloat, height: CGFloat,
        cornerRadius: CGFloat,
        fillPercent: Double,
        state: BarState
    ) {
        let trackRect = NSRect(x: x, y: y, width: width, height: height)
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: cornerRadius, yRadius: cornerRadius)
        trackColor.setFill()
        trackPath.fill()

        let fillFraction = max(0, min(1, fillPercent / 100.0))
        guard fillFraction > 0 else { return }

        let fillWidth = width * fillFraction
        let fillRect = NSRect(x: x, y: y, width: fillWidth, height: height)

        NSGraphicsContext.current?.saveGraphicsState()
        trackPath.addClip()
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius, yRadius: cornerRadius)
        state.color.setFill()
        fillPath.fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}
