import Foundation

public enum AmbientScene: String, Codable, CaseIterable, Identifiable, Sendable {
    case lunaStudy
    case lunaSleep
    case lunaRooftop
    case moonGarden
    case rainWindow
    case cityWindow
    case aurora
    case starlitShore

    /// First launch, and the scene shown when a saved Pro scene is locked.
    public static let defaultScene: AmbientScene = .lunaStudy

    public var id: String { rawValue }

    /// Luna Study and Moon Garden ship on the free plan. The rest are Pro.
    public var isPro: Bool {
        switch self {
        case .lunaStudy, .moonGarden:
            return false
        case .lunaSleep, .lunaRooftop, .rainWindow, .cityWindow, .aurora, .starlitShore:
            return true
        }
    }

    public var titleKey: String {
        switch self {
        case .lunaStudy: return "scene.lunaStudy"
        case .lunaSleep: return "scene.lunaSleep"
        case .lunaRooftop: return "scene.lunaRooftop"
        case .moonGarden: return "scene.moonGarden"
        case .rainWindow: return "scene.rainWindow"
        case .cityWindow: return "scene.cityWindow"
        case .aurora: return "scene.aurora"
        case .starlitShore: return "scene.starlitShore"
        }
    }

    /// Asset-catalog image. Procedural scenes have none.
    public var imageName: String? {
        switch self {
        case .lunaStudy: return "luna_focus"
        case .lunaSleep: return "luna_sleep"
        case .lunaRooftop: return "luna_rooftop"
        case .moonGarden, .rainWindow, .cityWindow, .aurora, .starlitShore:
            return nil
        }
    }

    public var isIllustrated: Bool { imageName != nil }

    /// Width divided by height of the bundled illustration.
    public var artworkAspect: Double? {
        switch self {
        case .lunaStudy:
            return 908.0 / 720.0
        case .lunaSleep, .lunaRooftop:
            return 1280.0 / 720.0
        case .moonGarden, .rainWindow, .cityWindow, .aurora, .starlitShore:
            return nil
        }
    }

    /// Unit point in the illustration. Luna sits center-right in each painting.
    public var focalPoint: ImageFocalPoint {
        switch self {
        case .lunaStudy: return ImageFocalPoint(x: 0.60, y: 0.46)
        case .lunaSleep: return ImageFocalPoint(x: 0.63, y: 0.50)
        case .lunaRooftop: return ImageFocalPoint(x: 0.72, y: 0.56)
        case .moonGarden, .rainWindow, .cityWindow, .aurora, .starlitShore:
            return ImageFocalPoint(x: 0.5, y: 0.5)
        }
    }
}

/// Whether the player should offer Luna Sleep while a sleep timer is running.
public enum SleepSceneOffer {
    public static let scene: AmbientScene = .lunaSleep

    public static func shouldOffer(sleepTimerActive: Bool, selected: AmbientScene, dismissed: Bool) -> Bool {
        sleepTimerActive && selected != scene && !dismissed
    }
}

/// Scene-chip titles. Split only on whitespace so a long word scales instead of breaking mid-word.
public enum SceneTitleLayout {
    public static func lines(for title: String) -> [String] {
        let words = title.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard words.count > 1 else { return [title] }
        let midpoint = (words.count + 1) / 2
        return [
            words[..<midpoint].joined(separator: " "),
            words[midpoint...].joined(separator: " ")
        ]
    }
}
