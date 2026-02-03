import Foundation

public enum UsageFileLocator {
    public struct Result: Sendable {
        public let url: URL
        public let source: String
    }

    public static func locate(overridePath: String?, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> Result? {
        if let overridePath, !overridePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = URL(fileURLWithPath: overridePath, isDirectory: false)
            if FileManager.default.fileExists(atPath: url.path) {
                return Result(url: url, source: "override")
            }
        }

        for candidate in defaultCandidates(homeDirectory: homeDirectory) {
            if FileManager.default.fileExists(atPath: candidate.url.path) {
                return candidate
            }
        }
        return nil
    }

    public static func defaultCandidates(homeDirectory: URL) -> [Result] {
        let claudeStats = homeDirectory.appendingPathComponent(".claude/stats-cache.json")
        return [
            Result(url: claudeStats, source: "claude-stats-cache")
        ]
    }
}
