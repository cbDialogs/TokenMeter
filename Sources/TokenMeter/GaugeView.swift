import SwiftUI

/// Analog speedometer: main needle = actual model usage, rim marker = expected pace,
/// lower sub-dial = 5-hour session usage. All values are 0–100.
struct GaugeView: View, Animatable {
    var actual: Double?
    var expected: Double
    var session: Double?
    var title: String
    var subtitle: String
    var sessionLabel: String
    var dimmed: Bool

    // Nil values animate from/to 0 but are not drawn.
    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(actual ?? 0, AnimatablePair(expected, session ?? 0)) }
        set {
            if actual != nil { actual = newValue.first }
            expected = newValue.second.first
            if session != nil { session = newValue.second.second }
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    // Main dial sweeps 240°, from bottom-left clockwise to bottom-right.
    private static let startAngle = 150.0
    private static let sweep = 240.0

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side / 2

            drawFace(&context, center: center, radius: radius)
            drawBands(&context, center: center, radius: radius)
            drawTicks(&context, center: center, radius: radius)
            drawSessionDial(&context, center: CGPoint(x: center.x, y: center.y + radius * 0.62), radius: radius * 0.27)
            drawExpectedMarker(&context, center: center, radius: radius)
            drawReadout(&context, center: center, radius: radius)
            if let actual {
                drawNeedle(&context, center: center, length: radius * 0.78, value: actual,
                           width: 4, color: needleColor)
            }
            drawHub(&context, center: center, radius: radius * 0.06)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Colors

    private var faceColor: Color { colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97) }
    private var rimColor: Color { colorScheme == .dark ? Color(white: 0.3) : Color(white: 0.75) }
    private var inkColor: Color { colorScheme == .dark ? Color(white: 0.9) : Color(white: 0.15) }
    private var mutedInk: Color { inkColor.opacity(0.55) }
    private var needleColor: Color { Color(red: 0.9, green: 0.25, blue: 0.2).opacity(dimmed ? 0.4 : 1) }
    private let greenBand = Color(red: 0.2, green: 0.7, blue: 0.35)
    private let amberBand = Color(red: 0.95, green: 0.7, blue: 0.15)
    private let redBand = Color(red: 0.9, green: 0.25, blue: 0.2)

    // MARK: Geometry

    private static func angle(for value: Double, start: Double = startAngle, sweep: Double = sweep) -> Angle {
        .degrees(start + sweep * min(max(value, 0), 100) / 100)
    }

    private static func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Angle) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle.radians), y: center.y + radius * sin(angle.radians))
    }

    // MARK: Drawing

    private func drawFace(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect.insetBy(dx: 2, dy: 2)), with: .color(faceColor))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 2, dy: 2)), with: .color(rimColor), lineWidth: 3)
    }

    /// Zones relative to pace: green up to expected, amber to expected+10, red beyond.
    private func drawBands(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let bandRadius = radius * 0.86
        let amberEnd = min(expected + 10, 100)
        let zones: [(Double, Double, Color)] = [
            (0, expected, greenBand),
            (expected, amberEnd, amberBand),
            (amberEnd, 100, redBand),
        ]
        for (from, to, color) in zones where to > from {
            var path = Path()
            path.addArc(center: center, radius: bandRadius,
                        startAngle: Self.angle(for: from), endAngle: Self.angle(for: to), clockwise: false)
            context.stroke(path, with: .color(color.opacity(0.35)), lineWidth: radius * 0.07)
        }
    }

    private func drawTicks(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        for value in stride(from: 0, through: 100, by: 2) {
            let isMajor = value % 10 == 0
            let angle = Self.angle(for: Double(value))
            let outer = radius * 0.93
            let inner = radius * (isMajor ? 0.80 : 0.86)
            var path = Path()
            path.move(to: Self.point(center, inner, angle))
            path.addLine(to: Self.point(center, outer, angle))
            context.stroke(path, with: .color(isMajor ? inkColor : mutedInk), lineWidth: isMajor ? 2 : 1)

            if value % 20 == 0 {
                let label = Text("\(value)").font(.system(size: radius * 0.09, weight: .medium, design: .rounded))
                    .foregroundStyle(inkColor)
                context.draw(label, at: Self.point(center, radius * 0.68, angle))
            }
        }
    }

    private func drawExpectedMarker(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let angle = Self.angle(for: expected)
        // Thin ghost needle.
        var ghost = Path()
        ghost.move(to: center)
        ghost.addLine(to: Self.point(center, radius * 0.8, angle))
        context.stroke(ghost, with: .color(inkColor.opacity(0.3)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

        // Hollow triangle on the rim pointing inward.
        let tip = Self.point(center, radius * 0.80, angle)
        let baseCenter = Self.point(center, radius * 0.95, angle)
        let perpendicular = Angle.radians(angle.radians + .pi / 2)
        let half = radius * 0.05
        var triangle = Path()
        triangle.move(to: tip)
        triangle.addLine(to: Self.point(baseCenter, half, perpendicular))
        triangle.addLine(to: Self.point(baseCenter, -half, perpendicular))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(faceColor))
        context.stroke(triangle, with: .color(inkColor), lineWidth: 2)
    }

    private func drawReadout(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let valueText = actual.map { "\(Int($0.rounded()))%" } ?? "--"
        context.draw(
            Text(valueText).font(.system(size: radius * 0.2, weight: .bold, design: .rounded))
                .foregroundStyle(inkColor.opacity(dimmed ? 0.4 : 1)),
            at: CGPoint(x: center.x, y: center.y + radius * 0.24))
        context.draw(
            Text(title).font(.system(size: radius * 0.075, weight: .semibold)).foregroundStyle(mutedInk),
            at: CGPoint(x: center.x, y: center.y - radius * 0.3))
        context.draw(
            Text(subtitle).font(.system(size: radius * 0.065)).foregroundStyle(mutedInk),
            at: CGPoint(x: center.x, y: center.y - radius * 0.2))
    }

    private func drawSessionDial(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        // Upper half-circle, 180° → 360°.
        var arc = Path()
        arc.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        context.stroke(arc, with: .color(rimColor), lineWidth: 2)
        for value in stride(from: 0, through: 100, by: 25) {
            let angle = Self.angle(for: Double(value), start: 180, sweep: 180)
            var tick = Path()
            tick.move(to: Self.point(center, radius * 0.8, angle))
            tick.addLine(to: Self.point(center, radius, angle))
            context.stroke(tick, with: .color(mutedInk), lineWidth: 1)
        }
        if let session {
            let angle = Self.angle(for: session, start: 180, sweep: 180)
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: Self.point(center, radius * 0.9, angle))
            context.stroke(needle, with: .color(Color.accentColor.opacity(dimmed ? 0.4 : 1)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        drawHub(&context, center: center, radius: radius * 0.1)
        context.draw(
            Text(sessionLabel).font(.system(size: max(radius * 0.26, 8))).foregroundStyle(mutedInk),
            at: CGPoint(x: center.x, y: center.y + radius * 0.35))
    }

    private func drawNeedle(_ context: inout GraphicsContext, center: CGPoint, length: CGFloat,
                            value: Double, width: CGFloat, color: Color) {
        let angle = Self.angle(for: value)
        let tip = Self.point(center, length, angle)
        let tail = Self.point(center, -length * 0.15, angle)
        let perpendicular = Angle.radians(angle.radians + .pi / 2)
        var path = Path()
        path.move(to: tip)
        path.addLine(to: Self.point(tail, width, perpendicular))
        path.addLine(to: Self.point(tail, -width, perpendicular))
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    private func drawHub(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(inkColor))
    }
}
