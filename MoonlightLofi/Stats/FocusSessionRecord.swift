import Foundation
import SwiftData

@Model
final class FocusSessionRecord {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var focusMinutes: Int

    init(id: UUID = UUID(), startedAt: Date, endedAt: Date, focusMinutes: Int) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.focusMinutes = focusMinutes
    }
}

enum MoonlightStore {
    static let container: ModelContainer = {
        let schema = Schema([FocusSessionRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memory])
            } catch {
                fatalError("Moonlight Lofi could not open a local store.")
            }
        }
    }()
}
