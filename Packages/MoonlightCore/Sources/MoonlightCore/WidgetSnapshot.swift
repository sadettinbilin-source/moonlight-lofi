import Foundation

public enum AppGroupID {
    public static let suite = "group.com.moonlightlofi.shared"
    public static let snapshotKey = "widget.snapshot.v1"
    public static let timerKey = "focus.timer.v1"
}

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var phase: FocusPhase
    public var isRunning: Bool
    public var startedAt: Date?
    public var endsAt: Date?
    public var streak: Int
    public var totalFocusMinutes: Int

    public init(
        phase: FocusPhase,
        isRunning: Bool,
        startedAt: Date?,
        endsAt: Date?,
        streak: Int,
        totalFocusMinutes: Int
    ) {
        self.phase = phase
        self.isRunning = isRunning
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.streak = streak
        self.totalFocusMinutes = totalFocusMinutes
    }

    public init(timer: FocusTimerSnapshot, streak: Int, totalFocusMinutes: Int) {
        phase = timer.isRunning ? timer.phase : .idle
        isRunning = timer.isRunning
        startedAt = timer.isRunning ? timer.phaseStartedAt : nil
        endsAt = timer.isRunning ? timer.endDate : nil
        self.streak = streak
        self.totalFocusMinutes = totalFocusMinutes
    }

    public static let empty = WidgetSnapshot(
        phase: .idle,
        isRunning: false,
        startedAt: nil,
        endsAt: nil,
        streak: 0,
        totalFocusMinutes: 0
    )
}

public enum SnapshotCoding {
    public static func timerData(_ snapshot: FocusTimerSnapshot) -> Data? {
        try? JSONEncoder().encode(snapshot)
    }

    public static func timer(from data: Data) -> FocusTimerSnapshot? {
        try? JSONDecoder().decode(FocusTimerSnapshot.self, from: data)
    }

    public static func widgetData(_ snapshot: WidgetSnapshot) -> Data? {
        try? JSONEncoder().encode(snapshot)
    }

    public static func widget(from data: Data) -> WidgetSnapshot? {
        try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
