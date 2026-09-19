import SwiftUI

struct TodayPalette {
    let hue: Double
    let dark: Bool
    var ink: Color { Color(hue: hue, saturation: dark ? 0.23 : 0.50, brightness: dark ? 0.92 : 0.36) }
    var fill: LinearGradient {
        LinearGradient(colors: [
            Color(hue: hue, saturation: dark ? 0.32 : 0.07, brightness: dark ? 0.20 : 0.98),
            Color(hue: hue, saturation: dark ? 0.40 : 0.23, brightness: dark ? 0.30 : 0.89)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    init(mood: TodayMood, dark: Bool) {
        self.dark = dark
        switch mood.kind {
        case .work: hue = 0.56
        case .makeup: hue = 0.09
        case .weekend, .rest: hue = 0.25
        case .holiday:
            switch mood.holidayName {
            case "春节": hue = 0.02
            case "中秋节": hue = 0.68
            case "清明节", "端午节": hue = 0.27
            default: hue = 0.43
            }
        }
    }
}

/// Lightweight vector scenery; no timers or looping animations behind the income counter.
struct TodayScene: View {
    let mood: TodayMood
    let finished: Bool
    let ink: Color

    private var coastal: Bool {
        mood.kind == .holiday && !["春节", "中秋节", "清明节", "端午节"].contains(mood.holidayName ?? "")
    }
    private var symbol: String {
        if finished { return "sun.horizon.fill" }
        if mood.kind == .makeup { return "cup.and.saucer.fill" }
        if mood.kind == .work { return "sun.max.fill" }
        switch mood.holidayName {
        case "春节": return "sparkles"
        case "中秋节": return "moon.stars.fill"
        default: return "leaf.fill"
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Canvas { context, size in
                func point(_ x: Double, _ y: Double) -> CGPoint {
                    CGPoint(x: size.width * x, y: size.height * y)
                }
                // Overlapping, translucent land / sea bands give the illustration depth.
                for layer in 0..<3 {
                    let offset = Double(layer) * 0.12
                    var land = Path()
                    land.move(to: point(-0.1, 0.76 + offset))
                    land.addCurve(to: point(1.1, 0.65 + offset), control1: point(0.3, 0.35 + offset), control2: point(0.65, 1.1 + offset))
                    land.addLine(to: point(1.1, 1.1))
                    land.addLine(to: point(-0.1, 1.1))
                    land.closeSubpath()
                    context.fill(land, with: .color(ink.opacity(0.05 + Double(layer) * 0.035)))
                }
                if coastal {
                    context.fill(Path(ellipseIn: CGRect(x: size.width * 0.14, y: size.height * 0.14, width: 34, height: 34)), with: .color(ink.opacity(0.14)))
                    // Two bent palms and tapered leaves, drawn in the same ink as the card.
                    for (x, scale) in [(0.73, 1.0), (0.89, 0.68)] {
                        let top = point(x - 0.06 * scale, 0.75 - 0.59 * scale)
                        var trunk = Path()
                        trunk.move(to: point(x, 0.9))
                        trunk.addQuadCurve(to: top, control: point(x + 0.015, 0.45))
                        context.stroke(trunk, with: .color(ink.opacity(0.65)), style: StrokeStyle(lineWidth: 3.5 * scale, lineCap: .round))
                        for (dx, dy) in [(-0.17, 0.15), (-0.15, -0.05), (-0.06, -0.12), (0.10, -0.10), (0.18, 0.02), (0.15, 0.20)] {
                            var leaf = Path()
                            leaf.move(to: top)
                            let end = CGPoint(x: top.x + size.width * dx * scale, y: top.y + size.height * dy * scale)
                            leaf.addQuadCurve(to: end, control: CGPoint(x: (top.x + end.x) / 2, y: min(top.y, end.y) - 17 * scale))
                            leaf.addQuadCurve(to: top, control: CGPoint(x: (top.x + end.x) / 2, y: (top.y + end.y) / 2))
                            context.fill(leaf, with: .color(ink.opacity(0.65)))
                        }
                    }
                    var breeze = Path()
                    breeze.move(to: point(0.12, 0.55))
                    breeze.addQuadCurve(to: point(0.44, 0.50), control: point(0.25, 0.44))
                    context.stroke(breeze, with: .color(ink.opacity(0.25)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
            if !coastal {
                Image(systemName: symbol)
                    .font(.system(size: 64, weight: .ultraLight))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(ink.opacity(0.65))
                    .padding(.trailing, 26)
                    .padding(.bottom, 15)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
