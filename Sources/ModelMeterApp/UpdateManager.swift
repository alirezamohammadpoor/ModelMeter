import AppKit
import Foundation

enum UpdateCheckResult: Equatable {
    case upToDate(current: String)
    case updateAvailable(latest: String)
    case error(message: String)
}

struct LatestRelease: Equatable {
    let tagName: String
    let htmlURL: URL
}

protocol GitHubReleaseChecking {
    func fetchLatestRelease() async throws -> LatestRelease
}

@MainActor
protocol SparkleUpdating {
    func checkForUpdates() throws
    func checkForUpdatesInBackground() throws
}

protocol ReleasePageOpening {
    func openReleasePage(_ url: URL)
}

struct ReleasePageOpener: ReleasePageOpening {
    func openReleasePage(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

struct GitHubReleaseService: GitHubReleaseChecking {
    private let releasesURL = URL(string: "https://api.github.com/repos/alirezamohammadpoor/ModelMeter/releases/latest")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLatestRelease() async throws -> LatestRelease {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "UpdateManager", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "GitHub API returned \(http.statusCode)."
            ])
        }

        let payload = try JSONDecoder().decode(LatestReleasePayload.self, from: data)
        return LatestRelease(tagName: payload.tagName, htmlURL: payload.htmlURL)
    }
}

@MainActor
struct UpdateCoordinator {
    let releaseService: GitHubReleaseChecking
    let sparkleUpdater: SparkleUpdating?
    let releasePageOpener: ReleasePageOpening

    init(
        releaseService: GitHubReleaseChecking = GitHubReleaseService(),
        sparkleUpdater: SparkleUpdating? = nil,
        releasePageOpener: ReleasePageOpening = ReleasePageOpener()
    ) {
        self.releaseService = releaseService
        self.sparkleUpdater = sparkleUpdater
        self.releasePageOpener = releasePageOpener
    }

    func checkNow(currentVersion: String) async -> UpdateCheckResult {
        do {
            let latest = try await releaseService.fetchLatestRelease()
            let normalizedLatest = Self.normalizeVersion(latest.tagName)
            let normalizedCurrent = Self.normalizeVersion(currentVersion)

            guard !normalizedLatest.isEmpty, !normalizedCurrent.isEmpty else {
                return .error(message: "Unable to parse app version.")
            }

            if Self.compareVersions(normalizedLatest, normalizedCurrent) == .orderedDescending {
                guard FeatureFlags.useSparkleUpdater, let sparkleUpdater else {
                    releasePageOpener.openReleasePage(latest.htmlURL)
                    return .updateAvailable(latest: latest.tagName)
                }

                do {
                    try sparkleUpdater.checkForUpdates()
                    return .updateAvailable(latest: latest.tagName)
                } catch {
                    releasePageOpener.openReleasePage(latest.htmlURL)
                    return .error(message: "Sparkle failed to start update. Opened release page instead.")
                }
            }

            return .upToDate(current: currentVersion)
        } catch {
            return .error(message: "Update check failed: \(error.localizedDescription)")
        }
    }

    static func normalizeVersion(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for idx in 0..<count {
            let l = idx < left.count ? left[idx] : 0
            let r = idx < right.count ? right[idx] : 0
            if l > r { return .orderedDescending }
            if l < r { return .orderedAscending }
        }

        return .orderedSame
    }
}

enum FeatureFlags {
    static let useSparkleUpdater: Bool = {
#if DEBUG
        // Debug default off; set USE_SPARKLE_UPDATER=1 to test Sparkle locally.
        return ProcessInfo.processInfo.environment["USE_SPARKLE_UPDATER"] == "1"
#else
        // Release default on; set USE_SPARKLE_UPDATER=0 to force GitHub-page fallback.
        return ProcessInfo.processInfo.environment["USE_SPARKLE_UPDATER"] != "0"
#endif
    }()
}

private struct LatestReleasePayload: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
