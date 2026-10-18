import Foundation

public enum FocusPhase: String, Codable, Equatable, Sendable {
    case idle
    case focus
    case shortBreak
    case longBreak

    public var titleKey: String {
        switch self {
        case .idle: return "phase.idle"
        case .focus: return "phase.focus"
        case .shortBreak: return "phase.shortBreak"
        case .longBreak: return "phase.longBreak"
        }
    }

    public func length(in settings: FocusSettings) -> TimeInterval {
        switch self {
        case .idle, .focus:
            return settings.focusLength
        case .shortBreak:
            return settings.shortBreakLength
        case .longBreak:
            return settings.longBreakLength
        }
    }
}

public struct FocusSettings: Codable, Equatable, Sendable {
    public var focusLength: TimeInterval
    public var shortBreakLength: TimeInterval
    public var longBreakLength: TimeInterval
    public var sessionsUntilLongBreak: Int
    public var autoContinue: Bool

    public init(
        focusLength: TimeInterval,
        shortBreakLength: TimeInterval,
        longBreakLength: TimeInterval,
        sessionsUntilLongBreak: Int,
        autoContinue: Bool
    ) {
        self.focusLength = focusLength
        self.shortBreakLength = shortBreakLength
        self.longBreakLength = longBreakLength
        self.sessionsUntilLongBreak = sessionsUntilLongBreak
        self.autoContinue = autoContinue
    }

    public static let standard = FocusSettings(
        focusLength: 25 * 60,
        shortBreakLength: 5 * 60,
        longBreakLength: 15 * 60,
        sessionsUntilLongBreak: 4,
        autoContinue: true
    )

    public func sanitized() -> FocusSettings {
        var copy = self
        copy.focusLength = min(180 * 60, max(60, focusLength))
        copy.shortBreakLength = min(60 * 60, max(60, shortBreakLength))
        copy.longBreakLength = min(60 * 60, max(60, longBreakLength))
        copy.sessionsUntilLongBreak = min(8, max(1, sessionsUntilLongBreak))
        return copy
    }
}

public struct FocusTimerSnapshot: Codable, Equatable, Sendable {
    public var phase: FocusPhase
    public var isRunning: Bool
    public var endDate: Date?
    public var phaseStartedAt: Date?
    public var remainingWhenPaused: TimeInterval?
    public var plannedLength: TimeInterval
    public var settings: FocusSettings
    public var completedFocusInCycle: Int
    public var suggestedPhase: FocusPhase
    public var lastFinished: FocusPhase?

    public init(
        phase: FocusPhase,
        isRunning: Bool,
        endDate: Date?,
        phaseStartedAt: Date?,
        remainingWhenPaused: TimeInterval?,
        plannedLength: TimeInterval,
        settings: FocusSettings,
        completedFocusInCycle: Int,
        suggestedPhase: FocusPhase,
        lastFinished: FocusPhase?
    ) {
        self.phase = phase
        self.isRunning = isRunning
        self.endDate = endDate
        self.phaseStartedAt = phaseStartedAt
        self.remainingWhenPaused = remainingWhenPaused
        self.plannedLength = plannedLength
        self.settings = settings
        self.completedFocusInCycle = completedFocusInCycle
        self.suggestedPhase = suggestedPhase
        self.lastFinished = lastFinished
    }

    public static let idle = FocusTimerSnapshot(
        phase: .idle,
        isRunning: false,
        endDate: nil,
        phaseStartedAt: nil,
        remainingWhenPaused: nil,
        plannedLength: FocusSettings.standard.focusLength,
        settings: .standard,
        completedFocusInCycle: 0,
        suggestedPhase: .focus,
        lastFinished: nil
    )
}

public struct CompletedInterval: Equatable, Sendable {
    public var phase: FocusPhase
    public var startedAt: Date
    public var endedAt: Date
    public var elapsed: TimeInterval
    public var finishedNaturally: Bool

    public init(
        phase: FocusPhase,
        startedAt: Date,
        endedAt: Date,
        elapsed: TimeInterval,
        finishedNaturally: Bool
    ) {
        self.phase = phase
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsed = elapsed
        self.finishedNaturally = finishedNaturally
    }
}

public struct ResolvedTimer: Equatable, Sendable {
    public var snapshot: FocusTimerSnapshot
    public var completed: [CompletedInterval]

    public init(snapshot: FocusTimerSnapshot, completed: [CompletedInterval]) {
        self.snapshot = snapshot
        self.completed = completed
    }
}

/// Date-based Pomodoro. Remaining time is always `endDate - now`, so a
/// suspended app does not lose or invent seconds. At most one interval is
/// completed when the app returns; missed breaks are not replayed.
public enum FocusTimerEngine {
    /// If the app notices the end within this window, and auto-continue is on,
    /// the next phase starts as if it began at the previous end date.
    public static let autoContinueGrace: TimeInterval = 15

    public static func remaining(in snapshot: FocusTimerSnapshot, now: Date) -> TimeInterval {
        if snapshot.isRunning, let endDate = snapshot.endDate {
            return max(0, endDate.timeIntervalSince(now))
        }
        if let paused = snapshot.remainingWhenPaused {
            return max(0, paused)
        }
        return upcomingPhase(snapshot).length(in: snapshot.settings)
    }

    public static func progress(in snapshot: FocusTimerSnapshot, now: Date) -> Double {
        if !snapshot.isRunning && snapshot.remainingWhenPaused == nil && snapshot.phase == .idle {
            return 1
        }
        let length = max(1, snapshot.plannedLength)
        return min(1, max(0, remaining(in: snapshot, now: now) / length))
    }

    public static func begin(_ snapshot: FocusTimerSnapshot, now: Date) -> FocusTimerSnapshot {
        if snapshot.isRunning {
            return snapshot
        }
        if snapshot.remainingWhenPaused != nil {
            return resume(snapshot, now: now)
        }
        return start(snapshot, phase: upcomingPhase(snapshot), now: now)
    }

    public static func pause(_ snapshot: FocusTimerSnapshot, now: Date) -> FocusTimerSnapshot {
        guard snapshot.isRunning else { return snapshot }
        var next = snapshot
        next.remainingWhenPaused = remaining(in: snapshot, now: now)
        next.isRunning = false
        next.endDate = nil
        return next
    }

    public static func resume(_ snapshot: FocusTimerSnapshot, now: Date) -> FocusTimerSnapshot {
        guard !snapshot.isRunning, let remain = snapshot.remainingWhenPaused else {
            return snapshot
        }
        var next = snapshot
        next.isRunning = true
        next.endDate = now.addingTimeInterval(remain)
        next.remainingWhenPaused = nil
        return next
    }

    public static func stop(_ snapshot: FocusTimerSnapshot, now: Date) -> ResolvedTimer {
        var completed: [CompletedInterval] = []
        if snapshot.phase == .focus, snapshot.isRunning || snapshot.remainingWhenPaused != nil {
            let elapsed = activeElapsed(snapshot, now: now)
            if elapsed >= 1, let started = snapshot.phaseStartedAt {
                completed.append(
                    CompletedInterval(
                        phase: .focus,
                        startedAt: started,
                        endedAt: now,
                        elapsed: elapsed,
                        finishedNaturally: false
                    )
                )
            }
        }
        var next = FocusTimerSnapshot.idle
        next.settings = snapshot.settings
        next.completedFocusInCycle = snapshot.completedFocusInCycle
        next.plannedLength = next.settings.focusLength
        return ResolvedTimer(snapshot: next, completed: completed)
    }

    public static func updateSettings(_ snapshot: FocusTimerSnapshot, _ settings: FocusSettings) -> FocusTimerSnapshot {
        var next = snapshot
        next.settings = settings.sanitized()
        if !next.isRunning && next.remainingWhenPaused == nil {
            next.plannedLength = upcomingPhase(next).length(in: next.settings)
        }
        return next
    }

    public static func resolve(_ snapshot: FocusTimerSnapshot, now: Date) -> ResolvedTimer {
        guard snapshot.isRunning, let endDate = snapshot.endDate, now >= endDate else {
            return ResolvedTimer(snapshot: snapshot, completed: [])
        }

        let started = snapshot.phaseStartedAt ?? endDate.addingTimeInterval(-snapshot.plannedLength)
        let interval = CompletedInterval(
            phase: snapshot.phase,
            startedAt: started,
            endedAt: endDate,
            elapsed: max(0, snapshot.plannedLength),
            finishedNaturally: true
        )

        var cycle = snapshot.completedFocusInCycle
        if snapshot.phase == .focus {
            cycle += 1
        }
        if snapshot.phase == .longBreak {
            cycle = 0
        }
        let following = nextPhase(
            after: snapshot.phase,
            completedFocusInCycle: cycle,
            sessionsUntilLongBreak: snapshot.settings.sessionsUntilLongBreak
        )
        let nextLength = following.length(in: snapshot.settings)
        let nextEnd = endDate.addingTimeInterval(nextLength)
        let withinGrace = now.timeIntervalSince(endDate) <= autoContinueGrace

        var next = snapshot
        next.completedFocusInCycle = cycle
        next.lastFinished = snapshot.phase
        next.remainingWhenPaused = nil

        if snapshot.settings.autoContinue && withinGrace && nextEnd > now {
            next.phase = following
            next.suggestedPhase = following
            next.isRunning = true
            next.phaseStartedAt = endDate
            next.plannedLength = nextLength
            next.endDate = nextEnd
            return ResolvedTimer(snapshot: next, completed: [interval])
        }

        next.phase = .idle
        next.suggestedPhase = following
        next.isRunning = false
        next.endDate = nil
        next.phaseStartedAt = nil
        next.plannedLength = nextLength
        return ResolvedTimer(snapshot: next, completed: [interval])
    }

    public static func nextPhase(
        after phase: FocusPhase,
        completedFocusInCycle: Int,
        sessionsUntilLongBreak: Int
    ) -> FocusPhase {
        switch phase {
        case .focus:
            if sessionsUntilLongBreak > 0 && completedFocusInCycle % sessionsUntilLongBreak == 0 {
                return .longBreak
            }
            return .shortBreak
        case .shortBreak, .longBreak, .idle:
            return .focus
        }
    }

    private static func start(_ snapshot: FocusTimerSnapshot, phase: FocusPhase, now: Date) -> FocusTimerSnapshot {
        let actual: FocusPhase = phase == .idle ? .focus : phase
        let duration = actual.length(in: snapshot.settings)
        var next = snapshot
        next.phase = actual
        next.suggestedPhase = actual
        next.isRunning = true
        next.phaseStartedAt = now
        next.endDate = now.addingTimeInterval(duration)
        next.remainingWhenPaused = nil
        next.plannedLength = duration
        next.lastFinished = nil
        return next
    }

    private static func upcomingPhase(_ snapshot: FocusTimerSnapshot) -> FocusPhase {
        snapshot.suggestedPhase == .idle ? .focus : snapshot.suggestedPhase
    }

    private static func activeElapsed(_ snapshot: FocusTimerSnapshot, now: Date) -> TimeInterval {
        let remain: TimeInterval
        if snapshot.isRunning, let endDate = snapshot.endDate {
            remain = max(0, endDate.timeIntervalSince(now))
        } else if let paused = snapshot.remainingWhenPaused {
            remain = max(0, paused)
        } else {
            return 0
        }
        return max(0, snapshot.plannedLength - remain)
    }
}
