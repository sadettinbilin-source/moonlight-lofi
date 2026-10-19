import MoonlightCore
import SwiftUI

struct SceneBackdrop: View {
    var scene: AmbientScene
    var still: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var paused: Bool { still || reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
            Canvas { context, size in
                draw(scene, in: context, size: size, date: timeline.date, animated: !paused)
            }
        }
        .modifier(BleedToEdges(enabled: !still))
        .accessibilityHidden(true)
    }
}

private struct BleedToEdges: ViewModifier {
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.ignoresSafeArea()
        } else {
            content
        }
    }
}

private func draw(
    _ scene: AmbientScene,
    in context: GraphicsContext,
    size: CGSize,
    date: Date,
    animated: Bool
) {
    let time = animated ? date.timeIntervalSinceReferenceDate : 0
    switch scene {
    case .lunaStudy, .lunaSleep, .lunaRooftop:
        fillGradient(context, size, top: rgb(0.07, 0.07, 0.14), bottom: rgb(0.03, 0.04, 0.08))
    case .moonGarden:
        drawMoonGarden(context, size, time)
    case .rainWindow:
        drawRainWindow(context, size, time, animated: animated)
    case .cityWindow:
        drawCityWindow(context, size, time)
    case .aurora:
        drawAurora(context, size, time)
    case .starlitShore:
        drawShore(context, size, time)
    }
}

private func drawMoonGarden(_ context: GraphicsContext, _ size: CGSize, _ time: TimeInterval) {
    fillGradient(context, size, top: rgb(0.10, 0.08, 0.22), bottom: rgb(0.03, 0.04, 0.09))
    let center = CGPoint(x: size.width * 0.72, y: size.height * 0.24)
    let radius = min(size.width, size.height) * 0.11
    fillGlow(context, center: center, radius: radius * 2.6, color: Color.white.opacity(0.28))
    fillCircle(context, center: center, radius: radius, color: rgb(0.95, 0.93, 1))
    fillCircle(
        context,
        center: CGPoint(x: center.x - radius * 0.25, y: center.y - radius * 0.1),
        radius: radius * 0.16,
        color: Color.white.opacity(0.45)
    )
    for index in 0..<34 {
        let seed = Double(index)
        let x = unit(seed) * size.width
        let y = unit(seed + 2.2) * size.height * 0.62
        let twinkle = 0.35 + 0.65 * abs(sin(time * 0.8 + seed))
        let radius = 0.8 + unit(seed + 5) * 1.5
        fillCircle(
            context,
            center: CGPoint(x: x, y: y),
            radius: radius,
            color: Color.white.opacity(twinkle)
        )
    }
    var hill = Path()
    hill.move(to: CGPoint(x: 0, y: size.height * 0.78))
    hill.addQuadCurve(
        to: CGPoint(x: size.width, y: size.height * 0.84),
        control: CGPoint(x: size.width * 0.42, y: size.height * 0.66)
    )
    hill.addLine(to: CGPoint(x: size.width, y: size.height))
    hill.addLine(to: CGPoint(x: 0, y: size.height))
    hill.closeSubpath()
    context.fill(hill, with: .color(rgb(0.05, 0.06, 0.12)))
}

private func drawRainWindow(_ context: GraphicsContext, _ size: CGSize, _ time: TimeInterval, animated: Bool) {
    fillGradient(context, size, top: rgb(0.07, 0.09, 0.16), bottom: rgb(0.10, 0.13, 0.22))
    let inset: CGFloat = 36
    let window = CGRect(x: inset, y: size.height * 0.12, width: size.width - inset * 2, height: size.height * 0.62)
    context.fill(Path(roundedRect: window, cornerRadius: 28), with: .color(rgb(0.05, 0.07, 0.14).opacity(0.55)))
    for index in 0..<18 {
        let seed = Double(index)
        let x = window.minX + 24 + unit(seed) * (window.width - 48)
        let y = window.minY + 30 + unit(seed + 1.7) * (window.height * 0.55)
        let lit = sin(time * 0.4 + seed) > -0.2
        fillCircle(
            context,
            center: CGPoint(x: x, y: y),
            radius: 2.2,
            color: (lit ? rgb(0.98, 0.86, 0.62) : rgb(0.25, 0.32, 0.48)).opacity(0.9)
        )
    }
    let drops = animated ? 26 : 14
    for index in 0..<drops {
        let seed = Double(index)
        let x = unit(seed + 0.4) * size.width
        let length = 12 + unit(seed + 2) * 18
        let speed = 80 + Double(unit(seed + 3)) * 70
        let travel = animated ? time * speed + Double(index) * 47 : Double(index) * 36
        let y = CGFloat(travel.truncatingRemainder(dividingBy: Double(size.height)))
        var line = Path()
        line.move(to: CGPoint(x: x, y: y))
        line.addLine(to: CGPoint(x: x - 3, y: y + length))
        context.stroke(line, with: .color(Color.white.opacity(0.28)), lineWidth: 1.1)
    }
    context.stroke(
        Path(roundedRect: window, cornerRadius: 28),
        with: .color(Color.white.opacity(0.18)),
        lineWidth: 2
    )
}

private func drawCityWindow(_ context: GraphicsContext, _ size: CGSize, _ time: TimeInterval) {
    fillGradient(context, size, top: rgb(0.05, 0.05, 0.14), bottom: rgb(0.12, 0.08, 0.16))
    let moon = CGPoint(x: size.width * 0.78, y: size.height * 0.16)
    fillGlow(context, center: moon, radius: 70, color: Color.white.opacity(0.2))
    fillCircle(context, center: moon, radius: 22, color: rgb(0.96, 0.94, 1))
    let ground = size.height * 0.78
    let widths: [CGFloat] = [0.16, 0.12, 0.2, 0.1, 0.18, 0.14]
    var x: CGFloat = 0
    for (index, widthRatio) in widths.enumerated() {
        let width = size.width * widthRatio
        let height = size.height * (0.18 + CGFloat(unit(Double(index) + 0.3)) * 0.28)
        let rect = CGRect(x: x, y: ground - height, width: width - 8, height: height + size.height * 0.3)
        context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(rgb(0.07, 0.08, 0.16)))
        var windowY = rect.minY + 12
        var column = 0
        while windowY < ground - 10 {
            var windowX = rect.minX + 8
            column = 0
            while windowX < rect.maxX - 8 {
                let seed = Double(index * 20 + column) + Double(windowY)
                let lit = sin(time * 0.35 + seed) > 0.15
                let pane = CGRect(x: windowX, y: windowY, width: 6, height: 8)
                context.fill(
                    Path(roundedRect: pane, cornerRadius: 1),
                    with: .color(lit ? rgb(0.98, 0.84, 0.55).opacity(0.85) : Color.white.opacity(0.05))
                )
                windowX += 14
                column += 1
            }
            windowY += 16
        }
        x += width
    }
}

private func drawAurora(_ context: GraphicsContext, _ size: CGSize, _ time: TimeInterval) {
    fillGradient(context, size, top: rgb(0.02, 0.05, 0.12), bottom: rgb(0.04, 0.03, 0.10))
    for index in 0..<20 {
        let seed = Double(index)
        fillCircle(
            context,
            center: CGPoint(x: unit(seed) * size.width, y: unit(seed + 4) * size.height * 0.45),
            radius: 1.1,
            color: Color.white.opacity(0.7)
        )
    }
    let colors = [rgb(0.45, 0.95, 0.78), rgb(0.62, 0.55, 0.98), rgb(0.35, 0.75, 0.95)]
    context.drawLayer { layer in
        layer.addFilter(.blur(radius: 18))
        for band in 0..<3 {
            var path = Path()
            let base = size.height * (0.28 + CGFloat(band) * 0.09)
            path.move(to: CGPoint(x: 0, y: base))
            let steps = 28
            for step in 0...steps {
                let x = size.width * CGFloat(step) / CGFloat(steps)
                let wave = sin(Double(step) * 0.45 + time * 0.35 + Double(band))
                let y = base + CGFloat(wave) * 26
                path.addLine(to: CGPoint(x: x, y: y))
            }
            layer.stroke(
                path,
                with: .color(colors[band].opacity(0.75)),
                style: StrokeStyle(lineWidth: 22, lineCap: .round)
            )
        }
    }
}

private func drawShore(_ context: GraphicsContext, _ size: CGSize, _ time: TimeInterval) {
    fillGradient(context, size, top: rgb(0.06, 0.07, 0.18), bottom: rgb(0.04, 0.08, 0.16))
    let horizon = size.height * 0.58
    let moon = CGPoint(x: size.width * 0.5, y: size.height * 0.28)
    fillGlow(context, center: moon, radius: 90, color: Color.white.opacity(0.22))
    fillCircle(context, center: moon, radius: 28, color: rgb(0.96, 0.94, 1))
    for index in 0..<16 {
        let seed = Double(index)
        fillCircle(
            context,
            center: CGPoint(x: unit(seed + 1) * size.width, y: unit(seed + 8) * horizon * 0.8),
            radius: 1,
            color: Color.white.opacity(0.75)
        )
    }
    var sea = Path()
    sea.move(to: CGPoint(x: 0, y: horizon))
    let steps = 36
    for step in 0...steps {
        let x = size.width * CGFloat(step) / CGFloat(steps)
        let y = horizon + CGFloat(sin(Double(step) * 0.55 + time * 0.9)) * 7
        sea.addLine(to: CGPoint(x: x, y: y))
    }
    sea.addLine(to: CGPoint(x: size.width, y: size.height))
    sea.addLine(to: CGPoint(x: 0, y: size.height))
    sea.closeSubpath()
    context.fill(sea, with: .color(rgb(0.06, 0.10, 0.20)))
    var reflection = Path()
    reflection.addEllipse(in: CGRect(x: moon.x - 8, y: horizon + 8, width: 16, height: size.height * 0.22))
    context.fill(reflection, with: .color(Color.white.opacity(0.16)))
}

private func fillGradient(_ context: GraphicsContext, _ size: CGSize, top: Color, bottom: Color) {
    let rect = Path(CGRect(origin: .zero, size: size))
    context.fill(
        rect,
        with: .linearGradient(
            Gradient(colors: [top, bottom]),
            startPoint: .zero,
            endPoint: CGPoint(x: size.width * 0.2, y: size.height)
        )
    )
}

private func fillCircle(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    context.fill(Path(ellipseIn: rect), with: .color(color))
}

private func fillGlow(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    context.fill(
        Path(ellipseIn: rect),
        with: .radialGradient(
            Gradient(colors: [color, color.opacity(0)]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    )
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(red: red, green: green, blue: blue)
}

func drawNightParticles(
    _ context: GraphicsContext,
    size: CGSize,
    time: TimeInterval,
    animated: Bool,
    starCount: Int,
    rainCount: Int
) {
    var layer = context
    layer.opacity = 0.42
    for index in 0..<starCount {
        let seed = Double(index) + 1.3
        let twinkle = animated ? 0.35 + 0.65 * abs(sin(time * 0.7 + seed)) : 0.7
        let radius = 0.7 + unit(seed + 5) * 1.3
        fillCircle(
            layer,
            center: CGPoint(x: unit(seed) * size.width, y: unit(seed + 2.2) * size.height * 0.72),
            radius: radius,
            color: Color.white.opacity(twinkle)
        )
    }
    let drops = animated ? rainCount : max(4, rainCount / 2)
    for index in 0..<drops {
        let seed = Double(index) + 0.6
        let x = unit(seed + 0.4) * size.width
        let length = 10 + unit(seed + 2) * 14
        let speed = 70 + Double(unit(seed + 3)) * 50
        let travel = animated ? time * speed + Double(index) * 41 : Double(index) * 28
        let y = CGFloat(travel.truncatingRemainder(dividingBy: Double(size.height)))
        var line = Path()
        line.move(to: CGPoint(x: x, y: y))
        line.addLine(to: CGPoint(x: x - 2.5, y: y + length))
        layer.stroke(line, with: .color(Color.white.opacity(0.55)), lineWidth: 1)
    }
}

private func unit(_ seed: Double) -> CGFloat {
    let value = sin(seed * 127.1 + 311.7) * 43758.5453
    return CGFloat(value - value.rounded(.down))
}

#Preview("Moon Garden") {
    SceneBackdrop(scene: .moonGarden)
}
