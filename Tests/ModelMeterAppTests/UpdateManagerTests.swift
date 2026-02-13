import XCTest
@testable import ModelMeterApp

@MainActor
final class UpdateManagerTests: XCTestCase {
    func testNormalizeVersionStripsVPrefix() {
        XCTAssertEqual(UpdateCoordinator.normalizeVersion("v1.2.3"), "1.2.3")
        XCTAssertEqual(UpdateCoordinator.normalizeVersion(" 2.0.0 "), "2.0.0")
    }

    func testCompareVersions() {
        XCTAssertEqual(UpdateCoordinator.compareVersions("1.2.0", "1.1.9"), .orderedDescending)
        XCTAssertEqual(UpdateCoordinator.compareVersions("1.2.0", "1.2.0"), .orderedSame)
        XCTAssertEqual(UpdateCoordinator.compareVersions("1.2", "1.2.1"), .orderedAscending)
    }

    func testCoordinatorReturnsUpToDateWhenEqual() async {
        let release = LatestRelease(tagName: "v1.0.0", htmlURL: URL(string: "https://example.com")!)
        let service = MockReleaseService(result: .success(release))
        let sparkle = MockSparkleUpdater()
        let opener = MockReleasePageOpener()
        let coordinator = UpdateCoordinator(releaseService: service, sparkleUpdater: sparkle, releasePageOpener: opener)

        let result = await coordinator.checkNow(currentVersion: "1.0.0")

        XCTAssertEqual(result, .upToDate(current: "1.0.0"))
        XCTAssertEqual(sparkle.checkForUpdatesCallCount, 0)
        XCTAssertNil(opener.openedURL)
    }

    func testCoordinatorTriggersUpdaterWhenNewer() async {
        let release = LatestRelease(tagName: "v1.2.0", htmlURL: URL(string: "https://example.com")!)
        let service = MockReleaseService(result: .success(release))
        let sparkle = MockSparkleUpdater()
        let opener = MockReleasePageOpener()
        let coordinator = UpdateCoordinator(releaseService: service, sparkleUpdater: sparkle, releasePageOpener: opener)

        let result = await coordinator.checkNow(currentVersion: "1.0.0")

        if FeatureFlags.useSparkleUpdater {
            XCTAssertEqual(sparkle.checkForUpdatesCallCount, 1)
            XCTAssertEqual(result, .updateAvailable(latest: "v1.2.0"))
        } else {
            XCTAssertEqual(sparkle.checkForUpdatesCallCount, 0)
            XCTAssertEqual(result, .updateAvailable(latest: "v1.2.0"))
            XCTAssertEqual(opener.openedURL, release.htmlURL)
        }
    }

    func testCoordinatorFallsBackToReleasePageWhenSparkleFails() async {
        let release = LatestRelease(tagName: "v1.2.0", htmlURL: URL(string: "https://example.com")!)
        let service = MockReleaseService(result: .success(release))
        let sparkle = MockSparkleUpdater(error: NSError(domain: "test", code: 1))
        let opener = MockReleasePageOpener()
        let coordinator = UpdateCoordinator(releaseService: service, sparkleUpdater: sparkle, releasePageOpener: opener)

        let result = await coordinator.checkNow(currentVersion: "1.0.0")

        if FeatureFlags.useSparkleUpdater {
            XCTAssertEqual(sparkle.checkForUpdatesCallCount, 1)
            XCTAssertEqual(opener.openedURL, release.htmlURL)
            XCTAssertEqual(result, .error(message: "Sparkle failed to start update. Opened release page instead."))
        } else {
            XCTAssertEqual(sparkle.checkForUpdatesCallCount, 0)
            XCTAssertEqual(opener.openedURL, release.htmlURL)
            XCTAssertEqual(result, .updateAvailable(latest: "v1.2.0"))
        }
    }

    func testCoordinatorReturnsErrorOnNetworkFailure() async {
        let service = MockReleaseService(result: .failure(NSError(domain: "test", code: 403)))
        let sparkle = MockSparkleUpdater()
        let opener = MockReleasePageOpener()
        let coordinator = UpdateCoordinator(releaseService: service, sparkleUpdater: sparkle, releasePageOpener: opener)

        let result = await coordinator.checkNow(currentVersion: "1.0.0")

        switch result {
        case let .error(message):
            XCTAssertTrue(message.contains("Update check failed"))
        default:
            XCTFail("Expected error result")
        }
    }
}

private struct MockReleaseService: GitHubReleaseChecking {
    let result: Result<LatestRelease, Error>

    func fetchLatestRelease() async throws -> LatestRelease {
        try result.get()
    }
}

@MainActor
private final class MockSparkleUpdater: SparkleUpdating {
    private(set) var checkForUpdatesCallCount = 0
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func checkForUpdates() throws {
        checkForUpdatesCallCount += 1
        if let error {
            throw error
        }
    }

    func checkForUpdatesInBackground() throws {}
}

private final class MockReleasePageOpener: ReleasePageOpening {
    private(set) var openedURL: URL?

    func openReleasePage(_ url: URL) {
        openedURL = url
    }
}
