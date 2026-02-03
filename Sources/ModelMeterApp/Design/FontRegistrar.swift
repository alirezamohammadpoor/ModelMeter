import CoreText
import Foundation

enum FontRegistrar {
    static func registerBundledFonts(in bundle: Bundle = .module) {
        let ttf = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        let otf = bundle.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? []
        let fontURLs = ttf + otf
        guard !fontURLs.isEmpty else { return }

        for url in fontURLs {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
