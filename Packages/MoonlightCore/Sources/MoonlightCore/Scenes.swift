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

/// Open sky between the scene picker and the track title, in the backdrop's own coordinates.
public struct MoonGap: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public static let zero = MoonGap(x: 0, y: 0, width: 0, height: 0)

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
}

public struct MoonDisc: Equatable, Sendable {
    public var centerX: Double
    public var centerY: Double
    public var radius: Double
    public var glow: Double

    public init(centerX: Double, centerY: Double, radius: Double, glow: Double) {
        self.centerX = centerX
        self.centerY = centerY
        self.radius = radius
        self.glow = glow
    }
}

/// Moon Garden's moon. Full-screen discs sit in the empty band under the scene picker,
/// on the right, with the glow kept inside that band so it cannot reach titles.
public enum MoonGardenLayout {
    /// iPhone 16 logical height. The open sky there is about y 330–520.
    public static let referenceHeight: Double = 852
    public static let referenceBandMinY: Double = 330
    public static let referenceBandMaxY: Double = 520

    public static func disc(canvasWidth: Double, canvasHeight: Double, gap: MoonGap) -> MoonDisc {
        if canvasHeight <= 500 {
            let radius = min(canvasWidth, canvasHeight) * 0.16
            return MoonDisc(
                centerX: canvasWidth * 0.62,
                centerY: canvasHeight * 0.28,
                radius: radius,
                glow: radius * 1.45
            )
        }

        let band = gap.width > 8 && gap.height > 8
            ? gap
            : fallbackBand(canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        let minX = max(band.x, 0)
        let maxX = min(band.maxX, canvasWidth)
        let minY = max(band.y, 0)
        let maxY = min(band.maxY, canvasHeight)
        let roomW = max(0, maxX - minX)
        let roomH = max(0, maxY - minY)
        let padX = roomW > 40 ? min(8, roomW * 0.06) : 0
        let padY = roomH > 40 ? min(12, roomH * 0.10) : 0
        let innerW = max(0, roomW - padX * 2)
        let innerH = max(0, roomH - padY * 2)
        let glow = min(16 * 1.45, innerW / 2, innerH / 2)
        let radius = glow / 1.45
        let centerY = minY + padY + innerH / 2
        let centerX = minX + padX + innerW - glow
        return MoonDisc(centerX: centerX, centerY: centerY, radius: radius, glow: glow)
    }

    public static func fallbackBand(canvasWidth: Double, canvasHeight: Double) -> MoonGap {
        let minY = canvasHeight * (referenceBandMinY / referenceHeight)
        let maxY = canvasHeight * (referenceBandMaxY / referenceHeight)
        return MoonGap(x: canvasWidth * 0.50, y: minY, width: canvasWidth * 0.50, height: maxY - minY)
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
