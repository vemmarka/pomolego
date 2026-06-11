import Foundation

struct GridCell: Hashable, Codable, Equatable {
    var col: Int
    var row: Int
}

struct PlacedBlock: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var col: Int
    var row: Int
    var designID: String
    var isCracked: Bool
    var placedAt: Date

    var cell: GridCell { GridCell(col: col, row: row) }
}

/// The persistent 2D block world. Row 0 is the ground (bottom) row;
/// rows grow upward.
struct World: Codable, Equatable {
    static let columns = 28
    static let rows = 14

    var blocks: [PlacedBlock] = []

    private var occupancy: Set<GridCell> {
        Set(blocks.map(\.cell))
    }

    func block(at cell: GridCell) -> PlacedBlock? {
        blocks.first { $0.col == cell.col && $0.row == cell.row }
    }

    func isOccupied(_ cell: GridCell) -> Bool {
        block(at: cell) != nil
    }

    func inBounds(_ cell: GridCell) -> Bool {
        (0..<World.columns).contains(cell.col) && (0..<World.rows).contains(cell.row)
    }

    /// Gravity rule: a block may sit on the ground row or directly on top of
    /// an occupied cell. No floating blocks.
    func isValidPlacement(_ cell: GridCell) -> Bool {
        guard inBounds(cell), !isOccupied(cell) else { return false }
        if cell.row == 0 { return true }
        return isOccupied(GridCell(col: cell.col, row: cell.row - 1))
    }

    var validCells: [GridCell] {
        let occupied = occupancy
        var result: [GridCell] = []
        for col in 0..<World.columns {
            // Exactly one valid cell per column: the lowest unoccupied cell
            // whose support exists (ground or top of the column's stack).
            var row = 0
            while occupied.contains(GridCell(col: col, row: row)) { row += 1 }
            let cell = GridCell(col: col, row: row)
            if inBounds(cell) { result.append(cell) }
        }
        return result
    }

    /// Number of occupied cells from the ground up in a column, assuming the
    /// column is a contiguous stack (which the gravity rule guarantees).
    func columnHeight(_ col: Int) -> Int {
        var row = 0
        while isOccupied(GridCell(col: col, row: row)) { row += 1 }
        return row
    }

    var mostRecentBlock: PlacedBlock? {
        blocks.max(by: { $0.placedAt < $1.placedAt })
    }

    /// Default target when the user starts without picking a spot:
    /// on top of the most recently placed block's column if valid,
    /// otherwise the nearest valid ground cell (nearest to that column,
    /// or to the world's center when the world is empty).
    func defaultTarget() -> GridCell? {
        if let recent = mostRecentBlock {
            let above = GridCell(col: recent.col, row: columnHeight(recent.col))
            if isValidPlacement(above) { return above }
            return nearestValidGroundCell(to: recent.col)
        }
        return nearestValidGroundCell(to: World.columns / 2)
    }

    func nearestValidGroundCell(to col: Int) -> GridCell? {
        validCells
            .filter { $0.row == 0 }
            .min(by: { abs($0.col - col) < abs($1.col - col) })
    }

    @discardableResult
    mutating func place(designID: String, isCracked: Bool, at cell: GridCell, date: Date) -> Bool {
        guard isValidPlacement(cell) else { return false }
        blocks.append(PlacedBlock(col: cell.col, row: cell.row,
                                  designID: designID, isCracked: isCracked, placedAt: date))
        return true
    }

    var builtCount: Int { blocks.filter { !$0.isCracked }.count }
    var crackedCount: Int { blocks.filter(\.isCracked).count }
}

struct ArchivedWorld: Codable, Equatable {
    var archivedAt: Date
    var blocks: [PlacedBlock]
}

/// On-disk representation of world.json: the live world plus archives
/// from "Start a fresh canvas".
struct WorldFile: Codable, Equatable {
    var current: World = World()
    var archived: [ArchivedWorld] = []
}
