import XCTest
@testable import MoonlightCore

final class SleepPlanTests: XCTestCase {
    func testFadeIsFullThenEasesToSilence() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plan = SleepPlan.make(now: now, duration: 30 * 60, fade: 10 * 60)
        XCTAssertEqual(plan.endsAt, now.addingTimeInterval(30 * 60))
        XCTAssertEqual(plan.volume(at: now), 1, accuracy: 0.0001)
        XCTAssertEqual(plan.volume(at: now.addingTimeInterval(20 * 60)), 1, accuracy: 0.0001)

        let midpoint = now.addingTimeInterval(25 * 60)
        XCTAssertEqual(plan.volume(at: midpoint), 0.7071067811865476, accuracy: 0.0001)
        XCTAssertEqual(plan.volume(at: plan.endsAt), 0, accuracy: 0.0001)
        XCTAssertEqual(plan.volume(at: plan.endsAt.addingTimeInterval(30)), 0, accuracy: 0.0001)
        XCTAssertFalse(plan.isFinished(at: midpoint))
        XCTAssertTrue(plan.isFinished(at: plan.endsAt))
    }

    func testFadeCannotExceedTheSleepDuration() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plan = SleepPlan.make(now: now, duration: 5 * 60, fade: 30 * 60)
        XCTAssertEqual(plan.fadeDuration, 5 * 60)
        let justAfterStart = plan.volume(at: now.addingTimeInterval(1))
        XCTAssertGreaterThan(justAfterStart, 0.99)
        XCTAssertLessThan(justAfterStart, 1)
    }

    func testZeroFadeStaysLoudUntilTheEnd() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plan = SleepPlan.make(now: now, duration: 60, fade: 0)
        XCTAssertEqual(plan.volume(at: now.addingTimeInterval(59)), 1, accuracy: 0.0001)
        XCTAssertEqual(plan.volume(at: now.addingTimeInterval(60)), 0, accuracy: 0.0001)
    }
}
