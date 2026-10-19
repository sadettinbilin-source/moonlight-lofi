import MoonlightCore
import SwiftUI

struct SceneThumbnail: View {
    var scene: AmbientScene

    var body: some View {
        GeometryReader { geo in
            if let name = scene.imageName {
                let placement = IllustratedMotion.placement(
                    imageAspect: scene.artworkAspect ?? 16.0 / 9.0,
                    viewWidth: Double(geo.size.width),
                    viewHeight: Double(geo.size.height),
                    focal: scene.focalPoint,
                    time: 0,
                    animated: false
                )
                Image(name)
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: CGFloat(placement.width), height: CGFloat(placement.height))
                    .offset(x: CGFloat(placement.originX), y: CGFloat(placement.originY))
            } else {
                SceneBackdrop(scene: scene, still: true)
            }
        }
        .frame(width: 72, height: 92)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipped()
        .accessibilityHidden(true)
    }
}
