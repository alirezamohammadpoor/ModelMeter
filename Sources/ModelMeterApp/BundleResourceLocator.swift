import Foundation

enum BundleResourceLocator {
    static func bundledScriptPath(fileName: String) -> String? {
        let fileManager = FileManager.default
        let resourceRoots = [
            Bundle.module.resourceURL,
            Bundle.main.resourceURL
        ]

        for root in resourceRoots {
            guard let root else { continue }
            let candidates = [
                root.appendingPathComponent("ModelMeterScripts", isDirectory: true).appendingPathComponent(fileName),
                root.appendingPathComponent(fileName)
            ]
            for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }

        return nil
    }
}
