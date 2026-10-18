import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A sleep timer that reaches silence at `endsAt`. Volume is derived from the
/// clock, so a gap in callbacks does not stall the fade.
public struct SleepPlan: Codable, Equatable, Sendable {
    public var endsAt: Date
    public var fadeDuration: TimeInterval

    public init(endsAt: Date, fadeDuration: TimeInterval) {
        self.endsAt = endsAt
        self.fadeDuration = fadeDuration
    }

    public static func make(now: Date, duration: TimeInterval, fade: TimeInterval) -> SleepPlan {
        let safeDuration = max(1, duration)
        let safeFade = min(max(0, fade), safeDuration)
        return SleepPlan(endsAt: now.addingTimeInterval(safeDuration), fadeDuration: safeFade)
    }

    public func isFinished(at date: Date) -> Bool {
        date >= endsAt
    }

    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    public static func decoded(_ data: Data) -> SleepPlan? {
        try? JSONDecoder().decode(SleepPlan.self, from: data)
    }

    /// 1 before the fade window, cosine ease to 0 at `endsAt`.
    public func volume(at date: Date) -> Double {
        if date >= endsAt {
            return 0
        }
        let fadeStart = endsAt.addingTimeInterval(-fadeDuration)
        if fadeDuration <= 0 || date <= fadeStart {
            return 1
        }
        let progress = min(1, max(0, date.timeIntervalSince(fadeStart) / fadeDuration))
        return cos(progress * Double.pi / 2)
    }
}
