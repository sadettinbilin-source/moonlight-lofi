import MoonlightCore
import SwiftUI

struct SceneThumbnail: View {
    var scene: AmbientScene

    var body: some View {
        GeometryReader { geo in
            if let name = scene.imageName {
                let placement = IllustratedMotion.placement(
                    imageAspect: scene.artworkAspect ?? 16.0 / 9.0,
                    viewWidth: geo.size.width,
                    viewHeight: geo.size.height,
                    focal: scene.focalPoint,
                    time: 0,
                    animated: false
                )
                Image(name)
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: placement.width, height: placement.height)
                    .offset(x: placement.originX, y: placement.originY)
            } else {
                SceneBackdrop(scene: scene, still: true)
            }
        }
        .frame(width: 72, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }
}
