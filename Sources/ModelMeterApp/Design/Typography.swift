import SwiftUI

enum VercelFonts {
    static func geistSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Geist Sans", size: size).weight(weight)
    }

    static func geistMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Geist Mono", size: size).weight(weight)
    }
}

enum VercelTextStyles {
    static func metricValue() -> Font {
        VercelFonts.geistMono(32, weight: .medium)
    }

    static func label() -> Font {
        VercelFonts.geistSans(11, weight: .regular)
    }

    static func sectionHeader() -> Font {
        VercelFonts.geistSans(11, weight: .medium)
    }

    static func body() -> Font {
        VercelFonts.geistSans(13, weight: .regular)
    }

    static func secondary() -> Font {
        VercelFonts.geistSans(12, weight: .regular)
    }

    static func monoData() -> Font {
        VercelFonts.geistMono(12, weight: .regular)
    }

    static func monoCaption() -> Font {
        VercelFonts.geistMono(11, weight: .regular)
    }
}
