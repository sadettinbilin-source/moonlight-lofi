import Foundation

public struct DayTotal: Equatable, Sendable {
    public var day: Date
    public var minutes: Int

    public init(day: Date, minutes: Int) {
        self.day = day
        self.minutes = minutes
    }
}

public enum FocusStats {
    public static func minutesCounted(phase: FocusPhase, elapsed: TimeInterval, finishedNaturally: Bool) -> Int {
        guard phase == .focus, elapsed >= 0 else { return 0 }
        if finishedNaturally {
            return max(1, Int((elapsed / 60).rounded()))
        }
        return Int(elapsed / 60)
    }

    public static func totalMinutes(_ values: [Int]) -> Int {
        values.reduce(0, +)
    }

    /// Today counts. If today is still empty, yesterday keeps the streak alive
    /// until the day ends. A gap before that drops it to zero.
    public static func currentStreak(sessionDays: [Date], today: Date, calendar: Calendar = .current) -> Int {
        let days = Set(sessionDays.map { calendar.startOfDay(for: $0) })
        let todayStart = calendar.startOfDay(for: today)
        var cursor = todayStart
        if !days.contains(cursor) {
            guard
                let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart),
                days.contains(yesterday)
            else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard streak < 10_000, let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return streak
    }

    /// Oldest day first, ending on `today`. Missing days are zero.
    public static func minutesByDay(
        records: [(date: Date, minutes: Int)],
        endingOn today: Date,
        days: Int = 7,
        calendar: Calendar = .current
    ) -> [DayTotal] {
        let end = calendar.startOfDay(for: today)
        var buckets: [Date: Int] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            buckets[day, default: 0] += max(0, record.minutes)
        }
        let count = max(1, days)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return DayTotal(day: day, minutes: buckets[day, default: 0])
        }
    }
}
