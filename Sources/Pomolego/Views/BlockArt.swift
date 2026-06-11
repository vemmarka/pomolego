import SwiftUI

/// All block artwork is drawn programmatically so it scales from menu-bar
/// size up to the panel and adapts to light/dark mode. One drawing case per
/// design id; everything is relative to `rect`.
enum BlockArt {
    static func draw(in context: GraphicsContext, rect: CGRect,
                     designID: String, isCracked: Bool = false) {
        let design = BlockDesign.design(for: isCracked ? BlockDesign.cracked.id : designID)
        let base = design.baseColor
        let accent = design.accentColor
        let shape = Path(roundedRect: rect, cornerRadius: 2.5)

        // Detail patterns are clipped to the rounded block shape so nothing
        // pokes past the corners (garden bushes intentionally rise above the
        // top edge and are drawn unclipped at the end).
        var inner = context
        inner.clip(to: shape)
        inner.fill(shape, with: .color(base))

        switch design.id {
        case "brick": drawBrick(inner, rect, accent: accent)
        case "glass": drawGlass(inner, rect, accent: accent)
        case "wood": drawWood(inner, rect, accent: accent)
        case "garden": drawGarden(inner, rect, accent: accent)
        case "stone": drawStone(inner, rect, accent: accent)
        case "neon": drawNeon(inner, rect, accent: accent)
        case "greenhouse": drawGreenhouse(inner, rect, accent: accent)
        case "marble": drawMarble(inner, rect, accent: accent)
        case "gold": drawGold(inner, rect, accent: accent)
        case "observatory": drawObservatory(inner, rect, accent: accent)
        case "cracked": drawCracked(inner, rect, accent: accent)
        default: break
        }

        // Subtle 3D edge treatment shared by every block.
        if design.id != "cracked" {
            var top = Path()
            top.move(to: CGPoint(x: rect.minX, y: rect.minY + 0.5))
            top.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 0.5))
            inner.stroke(top, with: .color(.white.opacity(0.30)), lineWidth: 1)
            var bottom = Path()
            bottom.move(to: CGPoint(x: rect.minX, y: rect.maxY - 0.5))
            bottom.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 0.5))
            inner.stroke(bottom, with: .color(.black.opacity(0.18)), lineWidth: 1)
        }
        if design.id == "garden" {
            drawGardenBushes(context, rect, accent: accent)
        }
        context.stroke(shape, with: .color(.black.opacity(0.10)), lineWidth: 0.5)
    }

    // MARK: - Per-design patterns

    private static func drawBrick(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        var mortar = Path()
        let rowH = r.height / 3
        for i in 1..<3 {
            let y = r.minY + rowH * CGFloat(i)
            mortar.move(to: CGPoint(x: r.minX, y: y))
            mortar.addLine(to: CGPoint(x: r.maxX, y: y))
        }
        // Staggered vertical joints per course.
        for course in 0..<3 {
            let y0 = r.minY + rowH * CGFloat(course)
            let offset = course.isMultiple(of: 2) ? r.width / 2 : r.width / 4
            for x in stride(from: r.minX + offset, to: r.maxX, by: r.width / 2) {
                mortar.move(to: CGPoint(x: x, y: y0))
                mortar.addLine(to: CGPoint(x: x, y: y0 + rowH))
            }
        }
        ctx.stroke(mortar, with: .color(accent.opacity(0.8)), lineWidth: 1)
    }

    private static func drawGlass(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        let inset = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.14)
        let cols = 3, rows = 2
        let w = inset.width / CGFloat(cols)
        let h = inset.height / CGFloat(rows)
        for row in 0..<rows {
            for col in 0..<cols {
                let pane = CGRect(x: inset.minX + CGFloat(col) * w + 1,
                                  y: inset.minY + CGFloat(row) * h + 1,
                                  width: w - 2, height: h - 2)
                ctx.fill(Path(pane), with: .color(accent.opacity(0.85)))
            }
        }
    }

    private static func drawWood(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        var planks = Path()
        for i in 1..<3 {
            let y = r.minY + r.height / 3 * CGFloat(i)
            planks.move(to: CGPoint(x: r.minX, y: y))
            planks.addLine(to: CGPoint(x: r.maxX, y: y))
        }
        ctx.stroke(planks, with: .color(accent.opacity(0.7)), lineWidth: 1)
        // Two knots.
        let k1 = CGRect(x: r.minX + r.width * 0.25, y: r.minY + r.height * 0.10,
                        width: r.width * 0.10, height: r.height * 0.12)
        let k2 = CGRect(x: r.minX + r.width * 0.62, y: r.minY + r.height * 0.72,
                        width: r.width * 0.10, height: r.height * 0.12)
        ctx.fill(Path(ellipseIn: k1), with: .color(accent.opacity(0.8)))
        ctx.fill(Path(ellipseIn: k2), with: .color(accent.opacity(0.8)))
    }

    /// Bushes poking over the top edge — drawn unclipped so they rise above
    /// the block.
    private static func drawGardenBushes(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        let radii: [CGFloat] = [0.18, 0.24, 0.16]
        let centers: [CGFloat] = [0.22, 0.52, 0.80]
        for (cx, radius) in zip(centers, radii) {
            let rad = r.width * radius * 0.5
            let bush = CGRect(x: r.minX + r.width * cx - rad,
                              y: r.minY - rad * 0.9,
                              width: rad * 2, height: rad * 2)
            ctx.fill(Path(ellipseIn: bush), with: .color(accent))
        }
    }

    private static func drawGarden(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        let centers: [CGFloat] = [0.22, 0.52, 0.80]
        // Stems and a lighter meadow band at the bottom.
        let band = CGRect(x: r.minX, y: r.maxY - r.height * 0.25,
                          width: r.width, height: r.height * 0.25)
        ctx.fill(Path(band), with: .color(.white.opacity(0.12)))
        var stems = Path()
        for cx in centers {
            stems.move(to: CGPoint(x: r.minX + r.width * cx, y: r.minY + r.height * 0.1))
            stems.addLine(to: CGPoint(x: r.minX + r.width * cx, y: r.minY + r.height * 0.45))
        }
        ctx.stroke(stems, with: .color(accent.opacity(0.9)), lineWidth: 1)
    }

    private static func drawStone(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        var joints = Path()
        let midY = r.midY
        joints.move(to: CGPoint(x: r.minX, y: midY))
        joints.addLine(to: CGPoint(x: r.maxX, y: midY))
        joints.move(to: CGPoint(x: r.minX + r.width * 0.38, y: r.minY))
        joints.addLine(to: CGPoint(x: r.minX + r.width * 0.33, y: midY))
        joints.move(to: CGPoint(x: r.minX + r.width * 0.68, y: midY))
        joints.addLine(to: CGPoint(x: r.minX + r.width * 0.72, y: r.maxY))
        ctx.stroke(joints, with: .color(accent.opacity(0.9)), lineWidth: 1.2)
        // A few chisel marks.
        var marks = Path()
        marks.move(to: CGPoint(x: r.minX + r.width * 0.15, y: r.minY + r.height * 0.25))
        marks.addLine(to: CGPoint(x: r.minX + r.width * 0.25, y: r.minY + r.height * 0.20))
        marks.move(to: CGPoint(x: r.minX + r.width * 0.55, y: r.minY + r.height * 0.70))
        marks.addLine(to: CGPoint(x: r.minX + r.width * 0.62, y: r.minY + r.height * 0.78))
        ctx.stroke(marks, with: .color(accent.opacity(0.6)), lineWidth: 1)
    }

    private static func drawNeon(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        var cross = Path()
        cross.move(to: CGPoint(x: r.minX, y: r.minY))
        cross.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        cross.move(to: CGPoint(x: r.maxX, y: r.minY))
        cross.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        // Soft glow: a wide translucent pass under a bright core stroke.
        ctx.stroke(cross, with: .color(accent.opacity(0.35)), lineWidth: 4)
        ctx.stroke(cross, with: .color(accent), lineWidth: 1.4)
    }

    private static func drawGreenhouse(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        var grid = Path()
        grid.move(to: CGPoint(x: r.midX, y: r.minY))
        grid.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        grid.move(to: CGPoint(x: r.minX, y: r.midY))
        grid.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        ctx.stroke(grid, with: .color(.white.opacity(0.45)), lineWidth: 1)
        // Plant silhouettes rising from the bottom.
        for cx in [0.25, 0.72] {
            var plant = Path()
            let x = r.minX + r.width * cx
            plant.move(to: CGPoint(x: x, y: r.maxY))
            plant.addLine(to: CGPoint(x: x, y: r.maxY - r.height * 0.45))
            plant.move(to: CGPoint(x: x, y: r.maxY - r.height * 0.30))
            plant.addLine(to: CGPoint(x: x - r.width * 0.08, y: r.maxY - r.height * 0.42))
            plant.move(to: CGPoint(x: x, y: r.maxY - r.height * 0.38))
            plant.addLine(to: CGPoint(x: x + r.width * 0.08, y: r.maxY - r.height * 0.50))
            ctx.stroke(plant, with: .color(accent), lineWidth: 1.2)
        }
    }

    private static func drawMarble(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        var vein = Path()
        vein.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.3))
        vein.addCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.55),
                      control1: CGPoint(x: r.minX + r.width * 0.35, y: r.minY + r.height * 0.15),
                      control2: CGPoint(x: r.minX + r.width * 0.6, y: r.minY + r.height * 0.75))
        var vein2 = Path()
        vein2.move(to: CGPoint(x: r.minX + r.width * 0.55, y: r.minY))
        vein2.addCurve(to: CGPoint(x: r.minX + r.width * 0.8, y: r.maxY),
                       control1: CGPoint(x: r.minX + r.width * 0.7, y: r.minY + r.height * 0.4),
                       control2: CGPoint(x: r.minX + r.width * 0.6, y: r.minY + r.height * 0.7))
        ctx.stroke(vein, with: .color(accent.opacity(0.55)), lineWidth: 1)
        ctx.stroke(vein2, with: .color(accent.opacity(0.4)), lineWidth: 0.8)
    }

    private static func drawGold(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        let frame = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.16)
        ctx.stroke(Path(frame), with: .color(accent), lineWidth: 1.5)
        ctx.stroke(Path(frame.insetBy(dx: 1.5, dy: 1.5)),
                   with: .color(.black.opacity(0.2)), lineWidth: 1)
    }

    private static func drawObservatory(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        // Dome occupying the upper half.
        var dome = Path()
        dome.addArc(center: CGPoint(x: r.midX, y: r.minY + r.height * 0.55),
                    radius: r.width * 0.32,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        dome.closeSubpath()
        ctx.fill(dome, with: .color(.white.opacity(0.14)))
        // Telescope slit.
        let slit = CGRect(x: r.midX - r.width * 0.05, y: r.minY + r.height * 0.12,
                          width: r.width * 0.10, height: r.height * 0.40)
        ctx.fill(Path(slit), with: .color(accent))
        // Stars.
        for (sx, sy) in [(0.15, 0.2), (0.85, 0.25), (0.2, 0.75), (0.82, 0.7)] {
            let star = CGRect(x: r.minX + r.width * sx, y: r.minY + r.height * sy,
                              width: 1.5, height: 1.5)
            ctx.fill(Path(ellipseIn: star), with: .color(accent.opacity(0.9)))
        }
    }

    private static func drawCracked(_ ctx: GraphicsContext, _ r: CGRect, accent: Color) {
        var crack = Path()
        crack.move(to: CGPoint(x: r.minX + r.width * 0.45, y: r.minY))
        crack.addLine(to: CGPoint(x: r.minX + r.width * 0.55, y: r.minY + r.height * 0.3))
        crack.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.minY + r.height * 0.55))
        crack.addLine(to: CGPoint(x: r.minX + r.width * 0.52, y: r.minY + r.height * 0.8))
        crack.addLine(to: CGPoint(x: r.minX + r.width * 0.46, y: r.maxY))
        crack.move(to: CGPoint(x: r.minX + r.width * 0.55, y: r.minY + r.height * 0.3))
        crack.addLine(to: CGPoint(x: r.minX + r.width * 0.75, y: r.minY + r.height * 0.42))
        crack.move(to: CGPoint(x: r.minX + r.width * 0.38, y: r.minY + r.height * 0.55))
        crack.addLine(to: CGPoint(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.65))
        ctx.stroke(crack, with: .color(accent), lineWidth: 1.2)
    }
}

/// A standalone swatch of a design, used in the picker and overlays.
struct BlockSwatch: View {
    let design: BlockDesign
    var isCracked: Bool = false

    var body: some View {
        Canvas { context, size in
            BlockArt.draw(in: context,
                          rect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1),
                          designID: design.id, isCracked: isCracked)
        }
    }
}
