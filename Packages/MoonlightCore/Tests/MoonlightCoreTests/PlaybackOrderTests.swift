import XCTest
@testable import MoonlightCore

final class PlaybackOrderTests: XCTestCase {
    private let ids = ["a", "b", "c"]

    func testLoopOffStopsAtTheEnd() {
        XCTAssertEqual(PlaybackOrder.nextID(after: "b", in: ids, shuffle: false, loop: .off, randomIndex: { _ in 0 }), "c")
        XCTAssertNil(PlaybackOrder.nextID(after: "c", in: ids, shuffle: false, loop: .off, randomIndex: { _ in 0 }))
        XCTAssertEqual(PlaybackOrder.nextID(after: nil, in: ids, shuffle: false, loop: .off, randomIndex: { _ in 0 }), "a")
    }

    func testLoopAllWraps() {
        XCTAssertEqual(PlaybackOrder.nextID(after: "c", in: ids, shuffle: false, loop: .all, randomIndex: { _ in 0 }), "a")
    }

    func testLoopOneRepeatsTheCurrentTrack() {
        XCTAssertEqual(PlaybackOrder.nextID(after: "b", in: ids, shuffle: true, loop: .one, randomIndex: { _ in 0 }), "b")
    }

    func testShuffleAvoidsImmediateRepeat() {
        let next = PlaybackOrder.nextID(after: "a", in: ids, shuffle: true, loop: .all, randomIndex: { _ in 0 })
        XCTAssertEqual(next, "b")
        let wrapped = PlaybackOrder.nextID(after: "a", in: ["only"], shuffle: true, loop: .off, randomIndex: { _ in 0 })
        XCTAssertEqual(wrapped, "only")
    }

    func testEmptyQueue() {
        XCTAssertNil(PlaybackOrder.nextID(after: nil, in: [], shuffle: false, loop: .all, randomIndex: { _ in 0 }))
        XCTAssertNil(PlaybackOrder.previousID(before: "a", in: [], loop: .all))
    }

    func testPreviousWrapsOnlyWhenLooping() {
        XCTAssertEqual(PlaybackOrder.previousID(before: "b", in: ids, loop: .off), "a")
        XCTAssertNil(PlaybackOrder.previousID(before: "a", in: ids, loop: .off))
        XCTAssertEqual(PlaybackOrder.previousID(before: "a", in: ids, loop: .all), "c")
    }

    func testLoopModeCycles() {
        XCTAssertEqual(LoopMode.off.next, .one)
        XCTAssertEqual(LoopMode.one.next, .all)
        XCTAssertEqual(LoopMode.all.next, .off)
    }
}
