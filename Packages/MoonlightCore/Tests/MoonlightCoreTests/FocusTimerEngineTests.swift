import XCTest
@testable import MoonlightCore

final class FocusTimerEngineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testRemainingCountsDownFromEndDate() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let later = start.addingTimeInterval(10 * 60)
        XCTAssertEqual(running.phase, .focus)
        XCTAssertEqual(running.endDate, start.addingTimeInterval(25 * 60))
        XCTAssertEqual(FocusTimerEngine.remaining(in: running, now: later), 15 * 60, accuracy: 0.001)
        XCTAssertEqual(FocusTimerEngine.remaining(in: running, now: start.addingTimeInterval(30 * 60)), 0)
    }

    func testIdleShowsUpcomingLength() {
        XCTAssertEqual(FocusTimerEngine.remaining(in: .idle, now: start), 25 * 60)
        XCTAssertEqual(FocusTimerEngine.progress(in: .idle, now: start), 1)
    }

    func testPauseFreezesRemainingAndResumeSchedulesFromNow() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let later = start.addingTimeInterval(10 * 60)
        let paused = FocusTimerEngine.pause(running, now: later)
        XCTAssertFalse(paused.isRunning)
        XCTAssertNil(paused.endDate)
        XCTAssertEqual(paused.remainingWhenPaused ?? -1, 15 * 60, accuracy: 0.001)

        let resumeAt = later.addingTimeInterval(20 * 60)
        let resumed = FocusTimerEngine.resume(paused, now: resumeAt)
        XCTAssertEqual(resumed.endDate, resumeAt.addingTimeInterval(15 * 60))
        XCTAssertNil(resumed.remainingWhenPaused)
        XCTAssertTrue(resumed.isRunning)
    }

    func testPauseDoesNotInflateAFinishedSession() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let paused = FocusTimerEngine.pause(running, now: start.addingTimeInterval(10 * 60))
        let resumeAt = start.addingTimeInterval(40 * 60)
        let resumed = FocusTimerEngine.resume(paused, now: resumeAt)
        let finishedAt = resumed.endDate ?? resumeAt
        let resolved = FocusTimerEngine.resolve(resumed, now: finishedAt)
        XCTAssertEqual(resolved.completed.first?.elapsed ?? -1, 25 * 60, accuracy: 0.001)
        XCTAssertEqual(resolved.completed.first?.finishedNaturally, true)
    }

    func testResolveBeforeEndIsANoOp() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let resolved = FocusTimerEngine.resolve(running, now: start.addingTimeInterval(10))
        XCTAssertTrue(resolved.completed.isEmpty)
        XCTAssertEqual(resolved.snapshot, running)
    }

    func testResolveWithinGraceStartsTheBreakFromTheScheduledEnd() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let end = start.addingTimeInterval(25 * 60)
        let resolved = FocusTimerEngine.resolve(running, now: end.addingTimeInterval(1))
        XCTAssertEqual(resolved.completed.count, 1)
        XCTAssertEqual(resolved.completed[0].phase, .focus)
        XCTAssertTrue(resolved.snapshot.isRunning)
        XCTAssertEqual(resolved.snapshot.phase, .shortBreak)
        XCTAssertEqual(resolved.snapshot.endDate, end.addingTimeInterval(5 * 60))
        XCTAssertEqual(resolved.snapshot.completedFocusInCycle, 1)
    }

    func testResolveAfterGraceDoesNotReplayTheBreak() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let end = start.addingTimeInterval(25 * 60)
        let resolved = FocusTimerEngine.resolve(running, now: end.addingTimeInterval(60))
        XCTAssertFalse(resolved.snapshot.isRunning)
        XCTAssertEqual(resolved.snapshot.phase, .idle)
        XCTAssertEqual(resolved.snapshot.suggestedPhase, .shortBreak)
        XCTAssertEqual(resolved.snapshot.lastFinished, .focus)
        XCTAssertEqual(resolved.snapshot.completedFocusInCycle, 1)
        XCTAssertNil(resolved.snapshot.endDate)
    }

    func testAutoContinueOffLeavesTheNextPhaseWaiting() {
        var snapshot = FocusTimerEngine.begin(.idle, now: start)
        snapshot.settings.autoContinue = false
        let end = start.addingTimeInterval(25 * 60)
        let resolved = FocusTimerEngine.resolve(snapshot, now: end)
        XCTAssertFalse(resolved.snapshot.isRunning)
        XCTAssertEqual(resolved.snapshot.suggestedPhase, .shortBreak)
    }

    func testFourthFocusLeadsToALongBreakAndResetsTheCycle() throws {
        var idle = FocusTimerSnapshot.idle
        idle.completedFocusInCycle = 3
        let running = FocusTimerEngine.begin(idle, now: start)
        let done = FocusTimerEngine.resolve(running, now: start.addingTimeInterval(25 * 60))
        XCTAssertEqual(done.snapshot.phase, .longBreak)
        XCTAssertEqual(done.snapshot.completedFocusInCycle, 4)
        XCTAssertTrue(done.snapshot.isRunning)

        let longEnd = try XCTUnwrap(done.snapshot.endDate)
        let after = FocusTimerEngine.resolve(done.snapshot, now: longEnd)
        XCTAssertEqual(after.snapshot.phase, .focus)
        XCTAssertEqual(after.snapshot.completedFocusInCycle, 0)
        XCTAssertEqual(after.completed.first?.phase, .longBreak)
    }

    func testBeginWhileRunningDoesNotRestart() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let again = FocusTimerEngine.begin(running, now: start.addingTimeInterval(5))
        XCTAssertEqual(again, running)
    }

    func testBeginWhilePausedResumes() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let paused = FocusTimerEngine.pause(running, now: start.addingTimeInterval(30))
        let resumed = FocusTimerEngine.begin(paused, now: start.addingTimeInterval(40))
        XCTAssertTrue(resumed.isRunning)
        XCTAssertEqual(resumed.remainingWhenPaused, nil)
    }

    func testStopRecordsPartialFocusAndClearsTheClock() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let stopped = FocusTimerEngine.stop(running, now: start.addingTimeInterval(125))
        XCTAssertEqual(stopped.completed.count, 1)
        XCTAssertFalse(stopped.completed[0].finishedNaturally)
        XCTAssertEqual(stopped.completed[0].elapsed, 125, accuracy: 0.01)
        XCTAssertEqual(stopped.snapshot.phase, .idle)
        XCTAssertFalse(stopped.snapshot.isRunning)
        XCTAssertEqual(stopped.snapshot.completedFocusInCycle, 0)
    }

    func testStopDuringABreakDoesNotRecordFocus() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        let end = start.addingTimeInterval(25 * 60)
        let onBreak = FocusTimerEngine.resolve(running, now: end).snapshot
        let stopped = FocusTimerEngine.stop(onBreak, now: end.addingTimeInterval(20))
        XCTAssertTrue(stopped.completed.isEmpty)
    }

    func testCustomLengthsAreHonoredOnTheNextStart() {
        var settings = FocusSettings.standard
        settings.focusLength = 50 * 60
        settings.shortBreakLength = 8 * 60
        let updated = FocusTimerEngine.updateSettings(.idle, settings)
        let running = FocusTimerEngine.begin(updated, now: start)
        XCTAssertEqual(running.plannedLength, 50 * 60)
        XCTAssertEqual(running.endDate, start.addingTimeInterval(50 * 60))
    }

    func testSettingsDoNotMoveAnInFlightEndDate() {
        let running = FocusTimerEngine.begin(.idle, now: start)
        var settings = FocusSettings.standard
        settings.focusLength = 10 * 60
        let updated = FocusTimerEngine.updateSettings(running, settings)
        XCTAssertEqual(updated.endDate, running.endDate)
        XCTAssertEqual(updated.plannedLength, 25 * 60)
        XCTAssertEqual(updated.settings.focusLength, 10 * 60)
    }

    func testSettingsAreClamped() {
        let wild = FocusSettings(
            focusLength: 10,
            shortBreakLength: 9_999,
            longBreakLength: 1,
            sessionsUntilLongBreak: 0,
            autoContinue: true
        )
        let sanitized = wild.sanitized()
        XCTAssertEqual(sanitized.focusLength, 60)
        XCTAssertEqual(sanitized.shortBreakLength, 60 * 60)
        XCTAssertEqual(sanitized.longBreakLength, 60)
        XCTAssertEqual(sanitized.sessionsUntilLongBreak, 1)
    }

    func testNextPhaseCycle() {
        XCTAssertEqual(FocusTimerEngine.nextPhase(after: .focus, completedFocusInCycle: 1, sessionsUntilLongBreak: 4), .shortBreak)
        XCTAssertEqual(FocusTimerEngine.nextPhase(after: .focus, completedFocusInCycle: 4, sessionsUntilLongBreak: 4), .longBreak)
        XCTAssertEqual(FocusTimerEngine.nextPhase(after: .shortBreak, completedFocusInCycle: 1, sessionsUntilLongBreak: 4), .focus)
        XCTAssertEqual(FocusTimerEngine.nextPhase(after: .longBreak, completedFocusInCycle: 0, sessionsUntilLongBreak: 4), .focus)
    }
}
