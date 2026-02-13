import Combine
import XCTest
@testable import ModelMeterApp

@MainActor
final class UpdateManagerTests: XCTestCase {

    // MARK: - Version Utilities

    func testNormalizeVersionStripsVPrefix() {
        XCTAssertEqual(UpdateManager.normalizeVersion("v1.2.3"), "1.2.3")
        XCTAssertEqual(UpdateManager.normalizeVersion(" 2.0.0 "), "2.0.0")
    }

    func testCompareVersions() {
        XCTAssertEqual(UpdateManager.compareVersions("1.2.0", "1.1.9"), .orderedDescending)
        XCTAssertEqual(UpdateManager.compareVersions("1.2.0", "1.2.0"), .orderedSame)
        XCTAssertEqual(UpdateManager.compareVersions("1.2", "1.2.1"), .orderedAscending)
    }

    // MARK: - State Mapping

    func testCheckingStateMapsToIsChecking() {
        let driver = MockSparkleDriver()
        let manager = UpdateManager(sparkleDriver: driver)

        driver.pushState(.checking)

        XCTAssertTrue(manager.isChecking)
        XCTAssertEqual(manager.statusText, "Checking for updates...")
        XCTAssertEqual(manager.statusLevel, .info)
    }

    func testAvailableStateMapsToWarning() {
        let driver = MockSparkleDriver()
        let manager = UpdateManager(sparkleDriver: driver)

        driver.pushState(.available(version: "2.0.0"))

        XCTAssertFalse(manager.isChecking)
        XCTAssertEqual(manager.statusText, "Update available (v2.0.0).")
        XCTAssertEqual(manager.statusLevel, .warning)
    }

    func testUpToDateStateMapsToSuccess() {
        let driver = MockSparkleDriver()
        let manager = UpdateManager(sparkleDriver: driver)

        driver.pushState(.upToDate)

        XCTAssertFalse(manager.isChecking)
        XCTAssertTrue(manager.statusText.contains("Up to date"))
        XCTAssertEqual(manager.statusLevel, .success)
    }

    func testFailedStateMapsToError() {
        let driver = MockSparkleDriver()
        let manager = UpdateManager(sparkleDriver: driver)

        driver.pushState(.failed(message: "Network error"))

        XCTAssertFalse(manager.isChecking)
        XCTAssertEqual(manager.statusText, "Network error")
        XCTAssertEqual(manager.statusLevel, .error)
    }

    func testIdleStateClearsStatus() {
        let driver = MockSparkleDriver()
        let manager = UpdateManager(sparkleDriver: driver)

        driver.pushState(.checking)
        XCTAssertTrue(manager.isChecking)

        driver.pushState(.idle)

        XCTAssertFalse(manager.isChecking)
        XCTAssertEqual(manager.statusText, "")
        XCTAssertEqual(manager.statusLevel, .none)
    }

    // MARK: - checkForUpdates Routing

    func testCheckForUpdatesCallsDriverWhenCanCheck() {
        let driver = MockSparkleDriver(canCheck: true)
        let manager = UpdateManager(sparkleDriver: driver)

        manager.checkForUpdates()

        XCTAssertEqual(driver.checkForUpdatesCallCount, 1)
    }

    func testCheckForUpdatesFallsBackWhenCannotCheck() {
        let driver = MockSparkleDriver(canCheck: false)
        let manager = UpdateManager(sparkleDriver: driver)

        manager.checkForUpdates()

        XCTAssertEqual(driver.checkForUpdatesCallCount, 0)
    }
}

// MARK: - Mock

@MainActor
private final class MockSparkleDriver: SparkleUpdateDriving {
    private let stateSubject = CurrentValueSubject<SparkleUpdateState, Never>(.idle)
    private(set) var checkForUpdatesCallCount = 0
    private let _canCheck: Bool

    var statePublisher: AnyPublisher<SparkleUpdateState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var canCheck: Bool { _canCheck }

    init(canCheck: Bool = false) {
        _canCheck = canCheck
    }

    func start() {}

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }

    func pushState(_ state: SparkleUpdateState) {
        stateSubject.send(state)
    }
}
