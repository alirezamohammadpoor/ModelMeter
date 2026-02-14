import AppKit
import ModelMeterCore

enum ProviderLogoAssets {
    static func image(for provider: UsageProvider) -> NSImage? {
        switch provider {
        case .claude: return claude
        case .codex: return openAI
        }
    }

    private static let claude = loadAny(named: "claude")
        ?? loadAny(named: "Claude_Logo_3")
    private static let openAI = loadAny(named: "OpenAI-white-monoblossom")
        ?? loadAny(named: "OpenAI-black-monoblossom")

    private static func loadAny(named resource: String) -> NSImage? {
        for ext in ["png", "svg"] {
            let candidates: [URL?] = [
                Bundle.module.url(forResource: resource, withExtension: ext, subdirectory: "Logos"),
                Bundle.module.url(forResource: resource, withExtension: ext)
            ]
            for url in candidates {
                if let url, let image = NSImage(contentsOf: url) {
                    image.isTemplate = true
                    return image
                }
            }
        }
        return nil
    }
}
