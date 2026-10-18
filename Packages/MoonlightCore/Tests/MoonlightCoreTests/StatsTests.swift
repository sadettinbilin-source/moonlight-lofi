import XCTest
@testable import MoonlightCore

final class StatsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func day(_ offset: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
    }

    func testMinutesCounted() {
        XCTAssertEqual(FocusStats.minutesCounted(phase: .focus, elapsed: 25 * 60, finishedNaturally: true), 25)
        XCTAssertEqual(FocusStats.minutesCounted(phase: .focus, elapsed: 125, finishedNaturally: false), 2)
        XCTAssertEqual(FocusStats.minutesCounted(phase: .focus, elapsed: 30, finishedNaturally: false), 0)
        XCTAssertEqual(FocusStats.minutesCounted(phase: .shortBreak, elapsed: 5 * 60, finishedNaturally: true), 0)
        XCTAssertEqual(FocusStats.minutesCounted(phase: .focus, elapsed: 20, finishedNaturally: true), 1)
    }

    func testTotalMinutes() {
        XCTAssertEqual(FocusStats.totalMinutes([25, 25, 10]), 60)
        XCTAssertEqual(FocusStats.totalMinutes([]), 0)
    }

    func testStreakRules() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let cal = calendar
        XCTAssertEqual(FocusStats.currentStreak(sessionDays: [], today: today, calendar: cal), 0)
        XCTAssertEqual(FocusStats.currentStreak(sessionDays: [today], today: today, calendar: cal), 1)
        XCTAssertEqual(
            FocusStats.currentStreak(sessionDays: [day(-1, from: today), today], today: today, calendar: cal),
            2
        )
        XCTAssertEqual(
            FocusStats.currentStreak(sessionDays: [day(-1, from: today)], today: today, calendar: cal),
            1,
            "Yesterday keeps the streak alive before today's session."
        )
        XCTAssertEqual(
            FocusStats.currentStreak(sessionDays: [day(-2, from: today)], today: today, calendar: cal),
            0
        )
        XCTAssertEqual(
            FocusStats.currentStreak(
                sessionDays: [day(-3, from: today), day(-1, from: today), today],
                today: today,
                calendar: cal
            ),
            2
        )
    }

    func testWeekBucketsAreOldestFirstAndFillGaps() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let records = [
            (date: today, minutes: 25),
            (date: today.addingTimeInterval(60), minutes: 5),
            (date: day(-2, from: today), minutes: 10)
        ]
        let week = FocusStats.minutesByDay(records: records, endingOn: today, days: 7, calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.last?.minutes, 30)
        XCTAssertEqual(week[week.count - 3].minutes, 10)
        XCTAssertEqual(week[0].minutes, 0)
        XCTAssertEqual(calendar.startOfDay(for: week.last?.day ?? today), calendar.startOfDay(for: today))
    }
}
