import AppKit
import Combine
import Foundation

// MARK: - UpdateManager

enum UpdateStatusLevel {
    case none, info, success, warning, error
}

@MainActor
@Observable
final class UpdateManager {
    static let shared = UpdateManager()

    private(set) var statusText: String = ""
    private(set) var statusLevel: UpdateStatusLevel = .none
    private(set) var isChecking: Bool = false

    private let sparkleDriver: SparkleUpdateDriving
    private var cancellables = Set<AnyCancellable>()

    init(sparkleDriver: SparkleUpdateDriving? = nil) {
        if let sparkleDriver {
            self.sparkleDriver = sparkleDriver
        } else if FeatureFlags.useSparkleUpdater {
            self.sparkleDriver = SparkleDriver()
        } else {
            self.sparkleDriver = NoopSparkleDriver()
        }
        subscribeToSparkleState()
    }

    func start() {
        sparkleDriver.start()
    }

    func checkForUpdates() {
        if sparkleDriver.canCheck {
            sparkleDriver.checkForUpdates()
        } else {
            Task {
                await checkViaGitHub()
            }
        }
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = (info["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let short, !short.isEmpty { return short }
        let build = (info["CFBundleVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (build?.isEmpty == false) ? build! : AppConstants.fallbackVersion
    }

    // MARK: - Private

    private func subscribeToSparkleState() {
        sparkleDriver.statePublisher
            .sink { [weak self] state in
                self?.applyState(state)
            }
            .store(in: &cancellables)
    }

    private func applyState(_ state: SparkleUpdateState) {
        switch state {
        case .idle:
            statusText = ""
            statusLevel = .none
            isChecking = false
        case .checking:
            statusText = "Checking for updates..."
            statusLevel = .info
            isChecking = true
        case .available(let version):
            statusText = "Update available (v\(version))."
            statusLevel = .warning
            isChecking = false
        case .upToDate:
            statusText = "Up to date (v\(Self.appVersion))."
            statusLevel = .success
            isChecking = false
        case .failed(let message):
            statusText = message
            statusLevel = .error
            isChecking = false
        }
    }

    private func checkViaGitHub() async {
        statusText = "Checking for updates..."
        statusLevel = .info
        isChecking = true

        do {
            let latest = try await GitHubReleaseService().fetchLatestRelease()
            let normalizedLatest = Self.normalizeVersion(latest.tagName)
            let normalizedCurrent = Self.normalizeVersion(Self.appVersion)

            guard !normalizedLatest.isEmpty, !normalizedCurrent.isEmpty else {
                statusText = "Unable to parse app version."
                statusLevel = .error
                isChecking = false
                return
            }

            if Self.compareVersions(normalizedLatest, normalizedCurrent) == .orderedDescending {
                NSWorkspace.shared.open(latest.htmlURL)
                statusText = "Update available (\(latest.tagName)). Opening release page..."
                statusLevel = .warning
            } else {
                statusText = "Up to date (v\(Self.appVersion))."
                statusLevel = .success
            }
        } catch {
            statusText = "Update check failed: \(error.localizedDescription)"
            statusLevel = .error
        }
        isChecking = false
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
