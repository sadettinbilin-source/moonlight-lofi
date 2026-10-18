import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A point in an image, in unit coordinates. `(0, 0)` is the top left.
public struct ImageFocalPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Where a landscape illustration is drawn inside a view after aspect-fill.
public struct ImagePlacement: Equatable, Sendable {
    public var originX: Double
    public var originY: Double
    public var width: Double
    public var height: Double
    public var scale: Double

    public func covers(viewWidth: Double, viewHeight: Double) -> Bool {
        originX <= 0.5
            && originY <= 0.5
            && originX + width >= viewWidth - 0.5
            && originY + height >= viewHeight - 0.5
    }
}

/// Slow Ken Burns crop. Scale and pan come from the clock, so a paused
/// timeline does not jump when it resumes.
public enum IllustratedMotion {
    public static let cycle: TimeInterval = 46
    public static let minimumScale: Double = 1.05
    public static let maximumScale: Double = 1.12

    /// `imageAspect` is width / height. `animated` is false for Reduce Motion
    /// and for layouts other than a portrait phone.
    public static func placement(
        imageAspect: Double,
        viewWidth: Double,
        viewHeight: Double,
        focal: ImageFocalPoint,
        time: TimeInterval,
        animated: Bool
    ) -> ImagePlacement {
        guard imageAspect > 0, viewWidth > 0, viewHeight > 0 else {
            return ImagePlacement(originX: 0, originY: 0, width: 0, height: 0, scale: 1)
        }

        let wave = animated ? sin(time * 2 * .pi / cycle) : 0
        let scale = animated
            ? minimumScale + (maximumScale - minimumScale) * (0.5 + 0.5 * wave)
            : minimumScale
        let base = max(viewWidth / imageAspect, viewHeight)
        let drawnWidth = imageAspect * base * scale
        let drawnHeight = base * scale

        let targetX = viewWidth * (0.50 + (animated ? 0.03 * wave : 0))
        let targetY = viewHeight * (0.40 + (animated ? 0.015 * sin(time * 2 * .pi / cycle + 0.8) : 0))

        var originX = targetX - focal.x * drawnWidth
        var originY = targetY - focal.y * drawnHeight
        originX = min(0, max(viewWidth - drawnWidth, originX))
        originY = min(0, max(viewHeight - drawnHeight, originY))

        return ImagePlacement(
            originX: originX,
            originY: originY,
            width: drawnWidth,
            height: drawnHeight,
            scale: scale
        )
    }
}
