import Foundation

public enum LoopMode: String, Codable, CaseIterable, Equatable, Sendable {
    case off
    case one
    case all

    public var next: LoopMode {
        switch self {
        case .off: return .one
        case .one: return .all
        case .all: return .off
        }
    }
}

public enum PlaybackOrder {
    /// `randomIndex` receives an exclusive upper bound and returns an index into that range.
    public static func nextID(
        after currentID: String?,
        in ids: [String],
        shuffle: Bool,
        loop: LoopMode,
        randomIndex: (Int) -> Int
    ) -> String? {
        guard !ids.isEmpty else { return nil }
        if loop == .one, let currentID, ids.contains(currentID) {
            return currentID
        }
        if shuffle {
            let pool = ids.filter { $0 != currentID }
            let choices = pool.isEmpty ? ids : pool
            let raw = randomIndex(choices.count)
            let index = abs(raw) % choices.count
            return choices[index]
        }
        guard let currentID, let index = ids.firstIndex(of: currentID) else {
            return ids[0]
        }
        let next = index + 1
        if next < ids.count {
            return ids[next]
        }
        return loop == .all ? ids[0] : nil
    }

    public static func previousID(before currentID: String?, in ids: [String], loop: LoopMode) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let currentID, let index = ids.firstIndex(of: currentID) else {
            return ids[0]
        }
        if index > 0 {
            return ids[index - 1]
        }
        switch loop {
        case .off:
            return nil
        case .one, .all:
            return ids[ids.count - 1]
        }
    }
}
