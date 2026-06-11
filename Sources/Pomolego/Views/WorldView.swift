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
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var canvas: some View {
        Canvas { context, size in
            drawGroundAndGrid(context, size: size)
            drawBlocks(context)
            if canPlace {
                drawValidCells(context)
                drawGhost(context)
            }
            drawInProgress(context)
        }
        .onTapGesture(coordinateSpace: .local) { location in
            let col = Int(location.x / Self.cellWidth)
            let rowFromTop = Int(location.y / Self.cellHeight)
            let row = World.rows - 1 - rowFromTop
            state.handleWorldTap(at: GridCell(col: col, row: row))
        }
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
        context.stroke(ground, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
    }

    private func drawBlocks(_ context: GraphicsContext) {
        for block in state.world.blocks {
            BlockArt.draw(in: context, rect: rect(for: block.cell),
                          designID: block.designID, isCracked: block.isCracked)
        }
    }

    private func drawValidCells(_ context: GraphicsContext) {
        for cell in state.world.validCells where cell != state.targetCell {
            let r = rect(for: cell).insetBy(dx: 2, dy: 2)
            context.stroke(Path(roundedRect: r, cornerRadius: 3),
                           with: .color(.secondary.opacity(0.30)),
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
                       with: .color(.accentColor),
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
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
