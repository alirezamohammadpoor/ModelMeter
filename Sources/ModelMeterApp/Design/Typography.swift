import SwiftUI

enum ModelMeterFonts {
    static func geistSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Geist Sans", size: size).weight(weight)
    }

    static func geistMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Geist Mono", size: size).weight(weight)
    }
}

enum ModelMeterTextStyles {
    // Geist Mono: percentages and countdown/timer values.
    static func metricValue() -> Font {
        ModelMeterFonts.geistMono(42, weight: .medium)
    }

    static func monoCaption() -> Font {
        ModelMeterFonts.geistMono(12, weight: .regular)
    }

    // Geist Sans: UI labels and controls.
    static func label() -> Font {
        ModelMeterFonts.geistSans(13, weight: .regular)
    }

    static func sectionHeader() -> Font {
        ModelMeterFonts.geistSans(12, weight: .medium)
    }

    static func body() -> Font {
        ModelMeterFonts.geistSans(13, weight: .regular)
    }

    static func secondary() -> Font {
        ModelMeterFonts.geistSans(13, weight: .regular)
    }

    static func monoData() -> Font {
        ModelMeterFonts.geistMono(12, weight: .regular)
    }
}
