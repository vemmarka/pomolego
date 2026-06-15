import SwiftUI

/// The persistent block world: a Canvas in a horizontal scroller.
/// Row 0 (ground) renders at the bottom. Valid cells are outlined whenever
/// placement is possible; tapping one sets the dashed ghost target.
struct WorldView: View {
    @EnvironmentObject var state: AppState

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
            }
        }
        .onTapGesture(coordinateSpace: .local) { location in
            let col = Int(location.x / Self.cellWidth)
            let rowFromTop = Int(location.y / Self.cellHeight)
            let row = World.rows - 1 - rowFromTop
            state.handleWorldTap(at: GridCell(col: col, row: row))
        }
    }

    /// A fish patrols each run of >= 3 contiguous water blocks, gliding end to
    /// end and back (sine motion, slowing at each turn).
    private func drawFish(_ context: GraphicsContext, date: Date) {
        let t = date.timeIntervalSinceReferenceDate
        for (i, run) in state.world.waterRuns.enumerated() {
            let cy = CGFloat(World.rows - 1 - run.row) * Self.cellHeight + Self.cellHeight / 2
            let margin: CGFloat = 7
            let minX = CGFloat(run.startCol) * Self.cellWidth + margin
            let maxX = CGFloat(run.endCol + 1) * Self.cellWidth - margin
            let mid = (minX + maxX) / 2
            let amp = (maxX - minX) / 2
            let period = max(3.0, Double(run.endCol - run.startCol + 1) * 1.4)
            let omega = 2 * Double.pi / period
            let phase = Double(run.row) * 0.7 + Double(run.startCol) * 0.5 + Double(i)
            let angle = t * omega + phase
            let x = mid + amp * CGFloat(sin(angle))
            drawFishShape(context, at: CGPoint(x: x, y: cy), facingRight: cos(angle) > 0)
        }
    }

    private func drawFishShape(_ context: GraphicsContext, at p: CGPoint, facingRight: Bool) {
        var ctx = context
        ctx.translateBy(x: p.x, y: p.y)
        if !facingRight { ctx.scaleBy(x: -1, y: 1) }
        let fish = Color(red: 1.0, green: 0.54, blue: 0.24)
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
