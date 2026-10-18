import MoonlightCore
import SwiftUI

/// Landscape painting, cropped around Luna. Portrait iPhones drift in a slow
/// Ken Burns pan. Reduce Motion, and every other size class, hold a still crop.
struct IllustratedScene: View {
    var scene: AmbientScene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var portraitPhone: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let placement = placement(in: geo.size, date: timeline.date)
                ZStack(alignment: .topLeading) {
                    if let name = scene.imageName {
                        Image(name)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: placement.width, height: placement.height)
                            .offset(x: placement.originX, y: placement.originY)
                    }
                    Canvas { context, size in
                        let rain = scene == .lunaRooftop ? 16 : 8
                        let stars = scene == .lunaSleep ? 16 : 22
                        drawNightParticles(
                            context,
                            size: size,
                            time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                            animated: !reduceMotion,
                            starCount: stars,
                            rainCount: rain
                        )
                    }
                    .allowsHitTesting(false)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.28), .black.opacity(0.62)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geo.size.height * 0.46)
                    }
                    .allowsHitTesting(false)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func placement(in size: CGSize, date: Date) -> ImagePlacement {
        IllustratedMotion.placement(
            imageAspect: scene.artworkAspect ?? 16.0 / 9.0,
            viewWidth: size.width,
            viewHeight: size.height,
            focal: scene.focalPoint,
            time: date.timeIntervalSinceReferenceDate,
            animated: portraitPhone && !reduceMotion
        )
    }
}
