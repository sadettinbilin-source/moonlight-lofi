import Foundation
import MoonlightCore

enum WidgetStore {
    static func load() -> WidgetSnapshot {
        guard
            let defaults = UserDefaults(suiteName: AppGroupID.suite),
            let data = defaults.data(forKey: AppGroupID.snapshotKey),
            let snapshot = SnapshotCoding.widget(from: data)
        else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard
            let defaults = UserDefaults(suiteName: AppGroupID.suite),
            let data = SnapshotCoding.widgetData(snapshot)
        else {
            return
        }
        defaults.set(data, forKey: AppGroupID.snapshotKey)
    }
}
