import Foundation

public enum AmbientScene: String, Codable, CaseIterable, Identifiable, Sendable {
    case moonGarden
    case rainWindow
    case cityWindow
    case aurora
    case starlitShore

    public var id: String { rawValue }

    /// Moon Garden ships with the free plan. The other four are Pro.
    public var isPro: Bool { self != .moonGarden }

    public var titleKey: String {
        switch self {
        case .moonGarden: return "scene.moonGarden"
        case .rainWindow: return "scene.rainWindow"
        case .cityWindow: return "scene.cityWindow"
        case .aurora: return "scene.aurora"
        case .starlitShore: return "scene.starlitShore"
        }
    }
}
