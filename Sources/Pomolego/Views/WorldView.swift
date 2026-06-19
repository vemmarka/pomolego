import SwiftUI

/// The persistent block world: a Canvas in a horizontal scroller.
/// Row 0 (ground) renders at the bottom. Valid cells are outlined whenever
/// placement is possible; tapping one sets the dashed ghost target.
struct WorldView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let cellWidth: CGFloat = 28
    static let cellHeight: CGFloat = 20

    private var contentWidth: CGFloat { CGFloat(World.columns) * Self.cellWidth }
    private var contentHeight: CGFloat { CGFloat(World.rows) * Self.cellHeight }

    private var canPlace: Bool {
        switch state.phase {
        case .idle, .focusRunning, .focusPaused: return true
        default: return false
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            canvas
                .frame(width: contentWidth, height: contentHeight)
        }
        .frame(height: contentHeight + 12)
        .background(
            LinearGradient(colors: [Color.primary.opacity(0.035), Color.primary.opacity(0.01)],
                           startPoint: .top, endPoint: .bottom)
        )
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.separator, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var canvas: some View {
        // TimelineView drives the continuous fish animation; the rest of the
        // scene is redrawn each frame too (cheap for this small grid).
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                drawGroundAndGrid(context, size: size)
                drawBlocks(context)
                if case .moving(let source) = state.editMode {
                    drawMoveDestinations(context, from: source)
                } else if canPlace {
                    drawValidCells(context)
                    if state.editMode == .none { drawGhost(context) }
                }
                drawSelection(context)
                drawInProgress(context)
                drawFish(context, date: timeline.date)
                drawFlowers(context, date: timeline.date)
                drawLavaEmbers(context, date: timeline.date)
                drawBlossomPetals(context, date: timeline.date)
                drawNeonLasers(context, date: timeline.date, reduceMotion: reduceMotion)
            }
        }
        .onTapGesture(coordinateSpace: .local) { location in
            let col = Int(location.x / Self.cellWidth)
            let rowFromTop = Int(location.y / Self.cellHeight)
            let row = World.rows - 1 - rowFromTop
            state.handleWorldTap(at: GridCell(col: col, row: row))
        }
    }

    // Time-driven so motion stays smooth. Runs of >= 5 water blocks get
    // rising bubbles and occasional fish loops.
    private static let richWater = 5
    private static let loopPeriod = 10.0, loopDuration = 1.3
    private static let fishColor = Color(red: 1.0, green: 0.54, blue: 0.24)

    /// A fish patrols each run of >= 3 contiguous water blocks (sine motion,
    /// slowing at each turn), plus the richer effects on >= 5-block runs.
    private func drawFish(_ context: GraphicsContext, date: Date) {
        let t = date.timeIntervalSinceReferenceDate
        for (i, run) in state.world.waterRuns.enumerated() {
            let rowTop = CGFloat(World.rows - 1 - run.row) * Self.cellHeight
            let cy = rowTop + Self.cellHeight / 2
            let margin: CGFloat = 7
            let minX = CGFloat(run.startCol) * Self.cellWidth + margin
            let maxX = CGFloat(run.endCol + 1) * Self.cellWidth - margin
            let len = run.endCol - run.startCol + 1
            let rich = len >= Self.richWater
            let seed = Double(run.row) * 0.7 + Double(run.startCol) * 0.5 + Double(i)

            if rich { drawBubbles(context, run: run, rowTop: rowTop, t: t, seed: seed) }

            let mid = (minX + maxX) / 2
            let amp = (maxX - minX) / 2
            let omega = 2 * Double.pi / max(3.0, Double(len) * 1.4)
            let angle = t * omega + seed
            var x = mid + amp * CGFloat(sin(angle))
            var y = cy
            if rich {
                let loopT = (t + seed * 3).truncatingRemainder(dividingBy: Self.loopPeriod)
                if loopT < Self.loopDuration {
                    let p = loopT / Self.loopDuration
                    let r = min(Self.cellHeight * 0.55, 8)
                    x += r * CGFloat(sin(2 * Double.pi * p))
                    y -= r * CGFloat(1 - cos(2 * Double.pi * p))
                }
            }
            drawFishShape(context, at: CGPoint(x: x, y: y), facingRight: cos(angle) > 0)
        }
    }

    private func drawBubbles(_ context: GraphicsContext, run: BlockRun, rowTop: CGFloat,
                             t: Double, seed: Double) {
        let left = CGFloat(run.startCol) * Self.cellWidth
        let width = CGFloat(run.endCol + 1) * Self.cellWidth - left
        let count = min(8, run.endCol - run.startCol + 1)
        for k in 0..<count {
            let rise = (t * (0.32 + 0.05 * Double(k % 3)) + Double(k) * 0.37 + seed)
                .truncatingRemainder(dividingBy: 1)
            let bx = left + (CGFloat(k) + 0.5) / CGFloat(count) * width
                + CGFloat(sin(t * 1.3 + Double(k))) * 2
            let by = rowTop + Self.cellHeight - CGFloat(rise) * Self.cellHeight
            let radius = 0.9 + (1 - CGFloat(rise)) * 1.0
            let alpha = 0.55 * (1 - rise) + 0.1
            context.fill(Path(ellipseIn: CGRect(x: bx - radius, y: by - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(.white.opacity(alpha)))
        }
    }

    /// Every Lava block glows with a gentle pulse and throws embers upward.
    private func drawLavaEmbers(_ context: GraphicsContext, date: Date) {
        let t = date.timeIntervalSinceReferenceDate
        for b in state.world.blocks where b.designID == "lava" && !b.isCracked {
            let x0 = CGFloat(b.col) * Self.cellWidth
            let y0 = CGFloat(World.rows - 1 - b.row) * Self.cellHeight
            let pulse = 0.12 + 0.10 * (0.5 + 0.5 * sin(t * 2 + Double(b.col) + Double(b.row)))
            context.fill(Path(roundedRect: CGRect(x: x0, y: y0, width: Self.cellWidth,
                                                  height: Self.cellHeight), cornerRadius: 2.5),
                         with: .color(Color(red: 1.0, green: 0.35, blue: 0.12).opacity(pulse)))
            let seed = Double(b.col) * 1.7 + Double(b.row) * 0.9
            for k in 0..<3 {
                let period = 1.8 + Double(k % 2) * 0.6
                let ph = (t / period + Double(k) * 0.4 + seed).truncatingRemainder(dividingBy: 1)
                let ex = x0 + Self.cellWidth * CGFloat(0.25 + 0.5 * ((Double(k) * 0.37 + seed)
                    .truncatingRemainder(dividingBy: 1))) + CGFloat(sin(t * 3 + Double(k))) * 1.5
                let ey = y0 - CGFloat(ph) * Self.cellHeight * 0.8
                let r = 1.3 * (1 - CGFloat(ph)) + 0.4
                context.fill(Path(ellipseIn: CGRect(x: ex - r, y: ey - r, width: r * 2, height: r * 2)),
                             with: .color(Color(red: 1.0, green: 0.66, blue: 0.16).opacity((1 - ph) * 0.9)))
            }
        }
    }

    /// Every Blossom block sheds petals that drift and sway downward.
    private func drawBlossomPetals(_ context: GraphicsContext, date: Date) {
        let t = date.timeIntervalSinceReferenceDate
        for b in state.world.blocks where b.designID == "blossom" && !b.isCracked {
            let x0 = CGFloat(b.col) * Self.cellWidth
            let yTop = CGFloat(World.rows - 1 - b.row) * Self.cellHeight
            let seed = Double(b.col) * 2.3 + Double(b.row) * 1.1
            for k in 0..<2 {
                let period = 3.2 + Double(k % 2) * 0.8
                let ph = (t / period + Double(k) * 0.5 + seed).truncatingRemainder(dividingBy: 1)
                let startX = x0 + Self.cellWidth * CGFloat(0.3 + 0.4 * ((Double(k) * 0.6 + seed)
                    .truncatingRemainder(dividingBy: 1)))
                let px = startX + CGFloat(sin(t * 1.5 + Double(k) + seed)) * 4
                let py = yTop + CGFloat(ph) * Self.cellHeight * 1.6
                var ctx = context
                ctx.translateBy(x: px, y: py)
                ctx.rotate(by: .radians(t * 1.2 + Double(k)))
                ctx.fill(Path(ellipseIn: CGRect(x: -2.2, y: -1.1, width: 4.4, height: 2.2)),
                         with: .color(Color(red: 0.97, green: 0.78, blue: 0.86).opacity((1 - ph) * 0.85 + 0.1)))
            }
        }
    }

    private static let neonPalette: [Color] = [
        Color(red: 1.0, green: 0.31, blue: 0.92), Color(red: 0.31, green: 0.92, blue: 1.0),
        Color(red: 0.55, green: 1.0, blue: 0.47), Color(red: 1.0, green: 0.90, blue: 0.35),
        Color(red: 0.71, green: 0.47, blue: 1.0), Color(red: 1.0, green: 0.55, blue: 0.27),
    ]

    /// A vertical stack of 3+ neon blocks throws a laser party: rotating,
    /// colour-cycling beams with an additive glow. Eased off under Reduce Motion.
    private func drawNeonLasers(_ context: GraphicsContext, date: Date, reduceMotion: Bool) {
        let runs = state.world.neonRuns
        guard !runs.isEmpty else { return }
        let t = date.timeIntervalSinceReferenceDate
        var ctx = context
        ctx.blendMode = .plusLighter
        let beams = 6
        let baseLen = Self.cellHeight * 3.4
        for run in runs {
            let ox = CGFloat(run.col) * Self.cellWidth + Self.cellWidth / 2
            let oyTop = CGFloat(World.rows - 1 - run.endRow) * Self.cellHeight
            let oyBot = CGFloat(World.rows - 1 - run.startRow) * Self.cellHeight + Self.cellHeight
            let oy = (oyTop + oyBot) / 2
            let seed = Double(run.col) * 1.3 + Double(run.startRow) * 0.7
            for k in 0..<beams {
                let dir: Double = k % 2 == 0 ? 1 : -1
                let angle = Double(k) / Double(beams) * 2 * .pi + seed + (reduceMotion ? 0 : t * 0.6 * dir)
                let lenPulse = reduceMotion ? 1 : 0.8 + 0.2 * sin(t * 3 + Double(k))
                let len = baseLen * CGFloat(lenPulse)
                let ex = ox + CGFloat(cos(angle)) * len
                let ey = oy + CGFloat(sin(angle)) * len
                let color = Self.neonPalette[(k + (reduceMotion ? 0 : Int(t))) % Self.neonPalette.count]
                var beam = Path()
                beam.move(to: CGPoint(x: ox, y: oy))
                beam.addLine(to: CGPoint(x: ex, y: ey))
                ctx.stroke(beam, with: .color(color.opacity(reduceMotion ? 0.16 : 0.22)), lineWidth: 4)
                ctx.stroke(beam, with: .color(color.opacity(reduceMotion ? 0.45 : 0.7)), lineWidth: 1.4)
            }
            let coreAlpha = reduceMotion ? 0.5 : max(0, 0.5 + 0.4 * sin(t * 5))
            ctx.fill(Path(ellipseIn: CGRect(x: ox - 2.5, y: oy - 2.5, width: 5, height: 5)),
                     with: .color(.white.opacity(coreAlpha)))
        }
    }

    private static let flowerColors: [Color] = [
        Color(red: 0.94, green: 0.51, blue: 0.67),
        Color(red: 0.96, green: 0.82, blue: 0.35),
        Color(red: 0.96, green: 0.96, blue: 0.96),
        Color(red: 0.92, green: 0.43, blue: 0.43),
    ]

    /// Flowers sprout on each run of >= 3 contiguous garden blocks — one per
    /// block, growing in over a couple of seconds (since the run completed)
    /// then swaying gently.
    private func drawFlowers(_ context: GraphicsContext, date: Date) {
        let t = date.timeIntervalSinceReferenceDate
        for run in state.world.gardenRuns {
            let rowTop = CGFloat(World.rows - 1 - run.row) * Self.cellHeight
            let newest = state.world.blocks
                .filter { $0.row == run.row && $0.designID == "garden"
                    && $0.col >= run.startCol && $0.col <= run.endCol }
                .map(\.placedAt).max()
            let age = newest.map { date.timeIntervalSince($0) } ?? 99
            for col in run.startCol...run.endCol {
                drawFlower(context, x: CGFloat(col) * Self.cellWidth + Self.cellWidth * 0.5,
                           rowTop: rowTop, col: col, t: t, age: age)
            }
        }
    }

    private func drawFlower(_ context: GraphicsContext, x: CGFloat, rowTop: CGFloat,
                            col: Int, t: Double, age: Double) {
        let g = max(0, min(1, (age - Double(col % 5) * 0.12) / 1.6)) // staggered grow-in
        guard g > 0 else { return }
        let gc = CGFloat(g)
        let baseY = rowTop + 2
        let height = Self.cellHeight * 0.85 * gc
        let sway = CGFloat(sin(t * 1.6 + Double(col) * 1.3)) * 2 * gc
        let tipX = x + sway
        let tipY = baseY - height

        var stem = Path()
        stem.move(to: CGPoint(x: x, y: baseY))
        stem.addQuadCurve(to: CGPoint(x: tipX, y: tipY),
                          control: CGPoint(x: (x + tipX) / 2, y: baseY - height * 0.5))
        context.stroke(stem, with: .color(Color(red: 0.27, green: 0.51, blue: 0.24)), lineWidth: 1)

        let color = Self.flowerColors[col % Self.flowerColors.count]
        let petalR = 1.8 * gc
        let dist = 2.6 * gc
        for k in 0..<5 {
            let a = Double(k) / 5 * 2 * Double.pi
            let px = tipX + CGFloat(cos(a)) * dist
            let py = tipY + CGFloat(sin(a)) * dist
            context.fill(Path(ellipseIn: CGRect(x: px - petalR, y: py - petalR,
                                                width: petalR * 2, height: petalR * 2)),
                         with: .color(color))
        }
        let cr = 1.3 * gc
        context.fill(Path(ellipseIn: CGRect(x: tipX - cr, y: tipY - cr, width: cr * 2, height: cr * 2)),
                     with: .color(Color(red: 0.98, green: 0.86, blue: 0.35)))
    }

    private func drawFishShape(_ context: GraphicsContext, at p: CGPoint, facingRight: Bool,
                               scale: CGFloat = 1, color: Color? = nil) {
        var ctx = context
        ctx.translateBy(x: p.x, y: p.y)
        if !facingRight { ctx.scaleBy(x: -1, y: 1) }
        if scale != 1 { ctx.scaleBy(x: scale, y: scale) }
        let fish = color ?? Self.fishColor
        ctx.fill(Path(ellipseIn: CGRect(x: -6, y: -3.6, width: 12, height: 7.2)), with: .color(fish))
        var tail = Path()
        tail.move(to: CGPoint(x: -5, y: 0))
        tail.addLine(to: CGPoint(x: -9.5, y: -3.4))
        tail.addLine(to: CGPoint(x: -9.5, y: 3.4))
        tail.closeSubpath()
        ctx.fill(tail, with: .color(fish))
        ctx.fill(Path(ellipseIn: CGRect(x: 1.8, y: -1.4, width: 1.7, height: 1.7)),
                 with: .color(.black.opacity(0.8)))
    }

    private func rect(for cell: GridCell) -> CGRect {
        CGRect(x: CGFloat(cell.col) * Self.cellWidth,
               y: CGFloat(World.rows - 1 - cell.row) * Self.cellHeight,
               width: Self.cellWidth, height: Self.cellHeight)
    }

    private func drawGroundAndGrid(_ context: GraphicsContext, size: CGSize) {
        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: size.height - 0.5))
        ground.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
        context.stroke(ground, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
    }

    private func drawBlocks(_ context: GraphicsContext) {
        for block in state.world.blocks {
            BlockArt.draw(in: context, rect: rect(for: block.cell),
                          designID: block.designID, isCracked: block.isCracked)
        }
    }

    private func drawValidCells(_ context: GraphicsContext) {
        for cell in state.world.validCells where cell != state.targetCell {
            let r = rect(for: cell).insetBy(dx: 2.5, dy: 2.5)
            context.stroke(Path(roundedRect: r, cornerRadius: 3.5),
                           with: .color(.secondary.opacity(0.12)),
                           style: StrokeStyle(lineWidth: 1))
        }
    }

    private func drawGhost(_ context: GraphicsContext) {
        guard let target = state.effectiveTarget else { return }
        let r = rect(for: target)
        var ghost = context
        ghost.opacity = 0.30
        BlockArt.draw(in: ghost, rect: r.insetBy(dx: 1, dy: 1),
                      designID: state.selectedDesignID)
        context.stroke(Path(roundedRect: r.insetBy(dx: 1, dy: 1), cornerRadius: 3),
                       with: .color(.appAccent),
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }

    /// Highlight ring on the block being edited; dashed while it's in
    /// move mode.
    private func drawSelection(_ context: GraphicsContext) {
        let cell: GridCell
        let dashed: Bool
        switch state.editMode {
        case .selected(let selected): cell = selected; dashed = false
        case .moving(let moving): cell = moving; dashed = true
        case .none: return
        }
        let r = rect(for: cell).insetBy(dx: 1, dy: 1)
        context.stroke(Path(roundedRect: r, cornerRadius: 3.5),
                       with: .color(.appAccent),
                       style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
    }

    /// Accent-tinted outlines on every cell the moving block may land on.
    private func drawMoveDestinations(_ context: GraphicsContext, from source: GridCell) {
        for cell in state.world.validMoveDestinations(from: source) {
            let r = rect(for: cell).insetBy(dx: 2.5, dy: 2.5)
            context.stroke(Path(roundedRect: r, cornerRadius: 3.5),
                           with: .color(.appAccent.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 1.2))
        }
    }

    /// The target cell fills bottom-to-top proportionally to elapsed time.
    private func drawInProgress(_ context: GraphicsContext) {
        guard state.phase.isFocus, let target = state.effectiveTarget else { return }
        let progress = state.sessionProgress
        guard progress > 0 else { return }
        let r = rect(for: target)
        let fillHeight = r.height * progress
        let clipRect = CGRect(x: r.minX, y: r.maxY - fillHeight,
                              width: r.width, height: fillHeight)
        var clipped = context
        clipped.clip(to: Path(clipRect))
        BlockArt.draw(in: clipped, rect: r, designID: state.selectedDesignID)
    }

    private var accessibilitySummary: String {
        let built = state.world.builtCount
        let cracked = state.world.crackedCount
        var summary = "World: \(built) block\(built == 1 ? "" : "s") built"
        if cracked > 0 { summary += ", \(cracked) cracked" }
        return summary
    }
}
