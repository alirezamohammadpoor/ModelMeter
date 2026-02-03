import XCTest
import ModelMeterCore

final class ThresholdGateTests: XCTestCase {
    func testFiresOncePerThreshold() {
        var gate = ThresholdGate()
        let now = Date()

        XCTAssertEqual(gate.nextThreshold(usedPercent: 61, resetAt: now), 60)
        XCTAssertNil(gate.nextThreshold(usedPercent: 62, resetAt: now))
        XCTAssertEqual(gate.nextThreshold(usedPercent: 81, resetAt: now), 80)
        XCTAssertNil(gate.nextThreshold(usedPercent: 91, resetAt: now))
        XCTAssertEqual(gate.nextThreshold(usedPercent: 96, resetAt: now), 95)
        XCTAssertNil(gate.nextThreshold(usedPercent: 100, resetAt: now))
    }

    func testResetsOnResetDateChange() {
        var gate = ThresholdGate()
        let now = Date()
        let later = now.addingTimeInterval(3600)

        XCTAssertEqual(gate.nextThreshold(usedPercent: 61, resetAt: now), 60)
        XCTAssertEqual(gate.nextThreshold(usedPercent: 61, resetAt: later), 60)
    }
}
