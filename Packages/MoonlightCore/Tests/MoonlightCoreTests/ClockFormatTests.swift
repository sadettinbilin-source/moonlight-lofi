import XCTest
@testable import MoonlightCore

final class ClockFormatTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(ClockFormat.mmss(0), "0:00")
        XCTAssertEqual(ClockFormat.mmss(8.9), "0:08")
        XCTAssertEqual(ClockFormat.mmss(25 * 60), "25:00")
        XCTAssertEqual(ClockFormat.mmss(90 * 60 + 5), "90:05")
        XCTAssertEqual(ClockFormat.mmss(-4), "0:00")
    }
}
