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

    /// Free placement: any in-bounds, unoccupied cell is valid. Blocks may
    /// float anywhere on the grid — there is no gravity/support requirement.
    func isValidPlacement(_ cell: GridCell) -> Bool {
        inBounds(cell) && !isOccupied(cell)
    }

    /// Every empty cell on the grid.
    var validCells: [GridCell] {
        let occupied = occupancy
        var result: [GridCell] = []
        for col in 0..<World.columns {
            for row in 0..<World.rows {
                let cell = GridCell(col: col, row: row)
                if !occupied.contains(cell) { result.append(cell) }
            }
        }
        return result
    }

    /// Highest occupied row in a column (+1), used only for the idle menu-bar
    /// skyline glyph. With free placement this is just "tallest filled row".
    func columnHeight(_ col: Int) -> Int {
        let rows = blocks.filter { $0.col == col }.map { $0.row }
        guard let top = rows.max() else { return 0 }
        return top + 1
    }

    var mostRecentBlock: PlacedBlock? {
        blocks.max(by: { $0.placedAt < $1.placedAt })
    }

    /// Default target when the user starts without picking a spot: directly
    /// above the most recently placed block (so consecutive sessions stack
    /// naturally) if that cell is free, otherwise a free cell near the
    /// bottom-center of the grid.
    func defaultTarget() -> GridCell? {
        if let recent = mostRecentBlock {
            let above = GridCell(col: recent.col, row: recent.row + 1)
            if isValidPlacement(above) { return above }
        }
        return nearestValidGroundCell(to: World.columns / 2) ?? validCells.first
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

    /// Removes a block. With free placement nothing falls — other blocks stay
    /// exactly where they are.
    @discardableResult
    mutating func removeBlock(at cell: GridCell) -> PlacedBlock? {
        guard let index = blocks.firstIndex(where: { $0.cell == cell }) else { return nil }
        return blocks.remove(at: index)
    }

    /// Where the block at `cell` could be moved: any other empty cell.
    func validMoveDestinations(from cell: GridCell) -> [GridCell] {
        guard isOccupied(cell) else { return [] }
        return validCells.filter { $0 != cell }
    }

    /// Moves a block to any empty in-bounds cell, keeping its identity
    /// (design, cracked state, placement date).
    @discardableResult
    mutating func moveBlock(from: GridCell, to: GridCell) -> Bool {
        guard from != to, let block = block(at: from), isValidPlacement(to) else { return false }
        removeBlock(at: from)
        var moved = block
        moved.col = to.col
        moved.row = to.row
        blocks.append(moved)
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
