import XCTest

final class PlacementTests: XCTestCase {
    private let date = Date(timeIntervalSinceReferenceDate: 0)

    private func makeWorld(columns: [(col: Int, height: Int)] = []) -> World {
        var world = World()
        for stack in columns {
            for row in 0..<stack.height {
                world.place(designID: "brick", isCracked: false,
                            at: GridCell(col: stack.col, row: row),
                            date: date.addingTimeInterval(Double(row)))
            }
        }
        return world
    }

    // MARK: - Gravity rule

    func testGroundCellsAreValidInEmptyWorld() {
        let world = makeWorld()
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 0, row: 0)))
        XCTAssertTrue(world.isValidPlacement(GridCell(col: World.columns - 1, row: 0)))
    }

    func testFloatingCellIsInvalid() {
        let world = makeWorld()
        XCTAssertFalse(world.isValidPlacement(GridCell(col: 3, row: 1)))
        XCTAssertFalse(world.isValidPlacement(GridCell(col: 3, row: 5)))
    }

    func testCellOnTopOfBlockIsValid() {
        let world = makeWorld(columns: [(col: 4, height: 2)])
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 4, row: 2)))
        XCTAssertFalse(world.isValidPlacement(GridCell(col: 4, row: 3)))
    }

    func testOccupiedCellIsInvalid() {
        let world = makeWorld(columns: [(col: 4, height: 2)])
        XCTAssertFalse(world.isValidPlacement(GridCell(col: 4, row: 0)))
        XCTAssertFalse(world.isValidPlacement(GridCell(col: 4, row: 1)))
    }

    func testOutOfBoundsIsInvalid() {
        let world = makeWorld(columns: [(col: 0, height: World.rows)])
        XCTAssertFalse(world.isValidPlacement(GridCell(col: -1, row: 0)))
        XCTAssertFalse(world.isValidPlacement(GridCell(col: World.columns, row: 0)))
        XCTAssertFalse(world.isValidPlacement(GridCell(col: 0, row: World.rows)))
    }

    func testSideBySideGroundPlacementNextToStack() {
        let world = makeWorld(columns: [(col: 10, height: 3)])
        // A new pile right next to an existing one starts at the ground.
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 11, row: 0)))
        XCTAssertFalse(world.isValidPlacement(GridCell(col: 11, row: 1)))
    }

    // MARK: - validCells

    func testValidCellsHasExactlyOnePerNonFullColumn() {
        let world = makeWorld(columns: [(col: 2, height: 3), (col: 7, height: 1)])
        let valid = world.validCells
        XCTAssertEqual(valid.count, World.columns)
        XCTAssertTrue(valid.contains(GridCell(col: 2, row: 3)))
        XCTAssertTrue(valid.contains(GridCell(col: 7, row: 1)))
        XCTAssertTrue(valid.contains(GridCell(col: 0, row: 0)))
        for cell in valid {
            XCTAssertTrue(world.isValidPlacement(cell))
        }
    }

    func testFullColumnHasNoValidCell() {
        let world = makeWorld(columns: [(col: 5, height: World.rows)])
        XCTAssertFalse(world.validCells.contains { $0.col == 5 })
    }

    // MARK: - Placement

    func testPlaceRejectsInvalidCell() {
        var world = makeWorld()
        XCTAssertFalse(world.place(designID: "brick", isCracked: false,
                                   at: GridCell(col: 0, row: 4), date: date))
        XCTAssertTrue(world.blocks.isEmpty)
    }

    func testPlaceAcceptsValidCellAndStacks() {
        var world = makeWorld()
        XCTAssertTrue(world.place(designID: "brick", isCracked: false,
                                  at: GridCell(col: 6, row: 0), date: date))
        XCTAssertTrue(world.place(designID: "glass", isCracked: false,
                                  at: GridCell(col: 6, row: 1),
                                  date: date.addingTimeInterval(1)))
        XCTAssertEqual(world.columnHeight(6), 2)
    }

    // MARK: - Default target

    func testDefaultTargetInEmptyWorldIsCenterGround() {
        let world = makeWorld()
        XCTAssertEqual(world.defaultTarget(), GridCell(col: World.columns / 2, row: 0))
    }

    func testDefaultTargetStacksOnMostRecentColumn() {
        var world = makeWorld()
        world.place(designID: "brick", isCracked: false,
                    at: GridCell(col: 3, row: 0), date: date)
        world.place(designID: "wood", isCracked: false,
                    at: GridCell(col: 9, row: 0), date: date.addingTimeInterval(10))
        XCTAssertEqual(world.defaultTarget(), GridCell(col: 9, row: 1))
    }

    func testDefaultTargetFallsBackToNearestGroundWhenColumnFull() {
        var world = makeWorld(columns: [(col: 0, height: World.rows - 1)])
        world.place(designID: "brick", isCracked: false,
                    at: GridCell(col: 0, row: World.rows - 1),
                    date: date.addingTimeInterval(100))
        XCTAssertEqual(world.defaultTarget(), GridCell(col: 1, row: 0))
    }

    // MARK: - Remove

    func testRemoveBlockCompactsColumnAbove() {
        var world = makeWorld(columns: [(col: 4, height: 4)])
        let removed = world.removeBlock(at: GridCell(col: 4, row: 1))
        XCTAssertNotNil(removed)
        XCTAssertEqual(world.columnHeight(4), 3)
        // No floating blocks: rows 0..2 occupied, row 3 free.
        XCTAssertTrue(world.isOccupied(GridCell(col: 4, row: 2)))
        XCTAssertFalse(world.isOccupied(GridCell(col: 4, row: 3)))
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 4, row: 3)))
    }

    func testRemoveTopBlock() {
        var world = makeWorld(columns: [(col: 2, height: 2)])
        world.removeBlock(at: GridCell(col: 2, row: 1))
        XCTAssertEqual(world.columnHeight(2), 1)
    }

    func testRemoveFromEmptyCellReturnsNil() {
        var world = makeWorld()
        XCTAssertNil(world.removeBlock(at: GridCell(col: 0, row: 0)))
    }

    func testRemoveDoesNotAffectOtherColumns() {
        var world = makeWorld(columns: [(col: 1, height: 2), (col: 2, height: 3)])
        world.removeBlock(at: GridCell(col: 1, row: 0))
        XCTAssertEqual(world.columnHeight(1), 1)
        XCTAssertEqual(world.columnHeight(2), 3)
    }

    // MARK: - Move

    func testMoveBlockToGroundElsewhere() {
        var world = makeWorld(columns: [(col: 3, height: 2)])
        XCTAssertTrue(world.moveBlock(from: GridCell(col: 3, row: 1),
                                      to: GridCell(col: 8, row: 0)))
        XCTAssertEqual(world.columnHeight(3), 1)
        XCTAssertTrue(world.isOccupied(GridCell(col: 8, row: 0)))
    }

    func testMoveBlockKeepsDesignAndCrackedState() {
        var world = makeWorld()
        world.place(designID: "cracked", isCracked: true,
                    at: GridCell(col: 0, row: 0), date: date)
        world.moveBlock(from: GridCell(col: 0, row: 0), to: GridCell(col: 5, row: 0))
        let moved = world.block(at: GridCell(col: 5, row: 0))
        XCTAssertEqual(moved?.designID, "cracked")
        XCTAssertEqual(moved?.isCracked, true)
    }

    func testMoveToFloatingCellFails() {
        var world = makeWorld(columns: [(col: 3, height: 1)])
        XCTAssertFalse(world.moveBlock(from: GridCell(col: 3, row: 0),
                                       to: GridCell(col: 8, row: 1)))
        XCTAssertTrue(world.isOccupied(GridCell(col: 3, row: 0)))
    }

    func testMoveBottomBlockWithinSameColumnToItsTop() {
        // Removing the bottom of a 3-stack drops the rest; the freed top
        // spot (row 2) is then a legal destination.
        var world = makeWorld(columns: [(col: 6, height: 3)])
        XCTAssertTrue(world.moveBlock(from: GridCell(col: 6, row: 0),
                                      to: GridCell(col: 6, row: 2)))
        XCTAssertEqual(world.columnHeight(6), 3)
    }

    func testValidMoveDestinationsExcludeSourceAndAccountForCompaction() {
        let world = makeWorld(columns: [(col: 6, height: 3)])
        let destinations = world.validMoveDestinations(from: GridCell(col: 6, row: 2))
        // The top of the now-2-high stack is where the block already sits
        // after compaction-removal, so its own cell is excluded.
        XCTAssertFalse(destinations.contains(GridCell(col: 6, row: 2)))
        XCTAssertTrue(destinations.contains(GridCell(col: 0, row: 0)))
        XCTAssertFalse(destinations.contains(GridCell(col: 0, row: 1)))
    }

    func testValidMoveDestinationsFromEmptyCellIsEmpty() {
        let world = makeWorld()
        XCTAssertTrue(world.validMoveDestinations(from: GridCell(col: 0, row: 0)).isEmpty)
    }

    // MARK: - Counts

    func testBuiltAndCrackedCounts() {
        var world = makeWorld()
        world.place(designID: "brick", isCracked: false,
                    at: GridCell(col: 1, row: 0), date: date)
        world.place(designID: "cracked", isCracked: true,
                    at: GridCell(col: 2, row: 0), date: date)
        XCTAssertEqual(world.builtCount, 1)
        XCTAssertEqual(world.crackedCount, 1)
    }
}
