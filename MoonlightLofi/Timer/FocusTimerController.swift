import ActivityKit
import Foundation
import MoonlightCore
import Observation
import UserNotifications
import WidgetKit

@MainActor
@Observable
final class FocusTimerController {
    private(set) var snapshot: FocusTimerSnapshot = .idle
    var statsProvider: () -> (streak: Int, minutes: Int) = { (0, 0) }
    var onCompleted: ((CompletedInterval) -> Void)?

    private var pending: [CompletedInterval] = []
    private let notifications = NotificationScheduler()
    private let live = LiveActivityController()

    init() {
        if let data = UserDefaults.standard.data(forKey: AppGroupID.timerKey),
           let saved = SnapshotCoding.timer(from: data) {
            snapshot = saved
        }
        let resolved = FocusTimerEngine.resolve(snapshot, now: Date())
        snapshot = resolved.snapshot
        pending = resolved.completed
        if snapshot.isRunning {
            notifications.reschedule(for: snapshot)
        } else {
            notifications.cancel()
        }
        Task { await live.sync(snapshot) }
    }

    func takePending() -> [CompletedInterval] {
        let copy = pending
        pending.removeAll()
        return copy
    }

    func enqueue(_ interval: CompletedInterval) {
        pending.append(interval)
    }

    func tick(now: Date) {
        apply(FocusTimerEngine.resolve(snapshot, now: now))
    }

    func begin() {
        let now = Date()
        apply(FocusTimerEngine.resolve(snapshot, now: now))
        let started = FocusTimerEngine.begin(snapshot, now: now)
        guard started != snapshot else { return }
        snapshot = started
        persist()
        Task {
            await notifications.requestAndSchedule(for: snapshot)
            await live.sync(snapshot)
        }
    }

    func pause() {
        snapshot = FocusTimerEngine.pause(snapshot, now: Date())
        persist()
        notifications.cancel()
        Task { await live.sync(snapshot) }
    }

    func stop() {
        apply(FocusTimerEngine.stop(snapshot, now: Date()))
    }

    func update(_ settings: FocusSettings) {
        snapshot = FocusTimerEngine.updateSettings(snapshot, settings)
        persist()
    }

    func persist() {
        if let data = SnapshotCoding.timerData(snapshot) {
            UserDefaults.standard.set(data, forKey: AppGroupID.timerKey)
        }
        let stats = statsProvider()
        WidgetStore.save(
            WidgetSnapshot(
                timer: snapshot,
                streak: stats.streak,
                totalFocusMinutes: stats.minutes
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    func notificationStatus() async -> UNAuthorizationStatus {
        await notifications.status()
    }

    func requestNotifications() async -> Bool {
        await notifications.requestAuthorization()
    }

    private func apply(_ resolved: ResolvedTimer) {
        let changed = resolved.snapshot != snapshot || !resolved.completed.isEmpty
        guard changed else { return }
        snapshot = resolved.snapshot
        for interval in resolved.completed {
            onCompleted?(interval)
        }
        persist()
        notifications.reschedule(for: snapshot)
        Task { await live.sync(snapshot) }
    }
}

@MainActor
final class NotificationScheduler {
    static let requestID = "focus.phase.end"
    private let center = UNUserNotificationCenter.current()

    func status() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    func requestAndSchedule(for snapshot: FocusTimerSnapshot) async {
        _ = await requestAuthorization()
        reschedule(for: snapshot)
    }

    func reschedule(for snapshot: FocusTimerSnapshot) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
        guard snapshot.isRunning, let end = snapshot.endDate else { return }
        let interval = end.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        if snapshot.phase == .focus {
            content.title = L10n.tr("focus.notificationFocus")
            content.body = L10n.tr("focus.notificationFocusBody")
        } else {
            content.title = L10n.tr("focus.notificationBreak")
            content.body = L10n.tr("focus.notificationBreakBody")
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.requestID, content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
    }
}

@MainActor
final class LiveActivityController {
    func sync(_ snapshot: FocusTimerSnapshot) async {
        let activities = Activity<FocusActivityAttributes>.activities
        let canRun = snapshot.isRunning
            && snapshot.phaseStartedAt != nil
            && snapshot.endDate != nil
            && (snapshot.phaseStartedAt ?? .distantPast) < (snapshot.endDate ?? .distantPast)
        guard canRun, ActivityAuthorizationInfo().areActivitiesEnabled,
              let startedAt = snapshot.phaseStartedAt,
              let endsAt = snapshot.endDate
        else {
            for activity in activities {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
            return
        }
        let state = FocusActivityAttributes.ContentState(
            startedAt: startedAt,
            endsAt: endsAt,
            phaseRaw: snapshot.phase.rawValue
        )
        let content = ActivityContent(state: state, staleDate: endsAt.addingTimeInterval(30))
        if let current = activities.first {
            await current.update(content)
            for extra in activities.dropFirst() {
                await extra.end(content, dismissalPolicy: .immediate)
            }
        } else {
            _ = try? Activity.request(
                attributes: FocusActivityAttributes(title: "Moonlight Lofi"),
                content: content
            )
        }
    }
}
