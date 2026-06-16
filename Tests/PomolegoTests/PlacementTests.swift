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

    // MARK: - Free placement

    func testGroundCellsAreValidInEmptyWorld() {
        let world = makeWorld()
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 0, row: 0)))
        XCTAssertTrue(world.isValidPlacement(GridCell(col: World.columns - 1, row: 0)))
    }

    func testFloatingCellIsValid() {
        // No gravity: a block can float anywhere on an empty grid.
        let world = makeWorld()
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 3, row: 1)))
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 3, row: 5)))
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 20, row: World.rows - 1)))
    }

    func testAnyEmptyCellIsValidRegardlessOfSupport() {
        let world = makeWorld(columns: [(col: 4, height: 2)])
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 4, row: 2)))   // on top
        XCTAssertTrue(world.isValidPlacement(GridCell(col: 4, row: 5)))   // floating above
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

    // MARK: - validCells

    func testValidCellsIsEveryEmptyCell() {
        let world = makeWorld(columns: [(col: 2, height: 3), (col: 7, height: 1)])
        let valid = world.validCells
        // Total cells minus the 4 occupied ones.
        XCTAssertEqual(valid.count, World.columns * World.rows - 4)
        XCTAssertTrue(valid.contains(GridCell(col: 2, row: 3)))   // on top of a stack
        XCTAssertTrue(valid.contains(GridCell(col: 7, row: 9)))   // floating
        XCTAssertTrue(valid.contains(GridCell(col: 0, row: 0)))   // ground
        XCTAssertFalse(valid.contains(GridCell(col: 2, row: 0)))  // occupied
        for cell in valid {
            XCTAssertTrue(world.isValidPlacement(cell))
        }
    }

    func testFullColumnHasNoValidCell() {
        let world = makeWorld(columns: [(col: 5, height: World.rows)])
        XCTAssertFalse(world.validCells.contains { $0.col == 5 })
    }

    // MARK: - Placement

    func testPlaceRejectsOccupiedCell() {
        var world = makeWorld(columns: [(col: 0, height: 1)])
        XCTAssertFalse(world.place(designID: "brick", isCracked: false,
                                   at: GridCell(col: 0, row: 0), date: date))
        XCTAssertEqual(world.blocks.count, 1)
    }

    func testPlaceAcceptsFloatingCell() {
        var world = makeWorld()
        XCTAssertTrue(world.place(designID: "brick", isCracked: false,
                                  at: GridCell(col: 6, row: 5), date: date))
        XCTAssertTrue(world.isOccupied(GridCell(col: 6, row: 5)))
        XCTAssertFalse(world.isOccupied(GridCell(col: 6, row: 0)))  // nothing below
    }

    // MARK: - Default target

    func testDefaultTargetInEmptyWorldIsCenterGround() {
        let world = makeWorld()
        XCTAssertEqual(world.defaultTarget(), GridCell(col: World.columns / 2, row: 0))
    }

    func testDefaultTargetStacksAboveMostRecentBlock() {
        var world = makeWorld()
        world.place(designID: "brick", isCracked: false,
                    at: GridCell(col: 3, row: 0), date: date)
        // Most recent is a floating block; default stacks directly above it.
        world.place(designID: "wood", isCracked: false,
                    at: GridCell(col: 9, row: 4), date: date.addingTimeInterval(10))
        XCTAssertEqual(world.defaultTarget(), GridCell(col: 9, row: 5))
    }

    // MARK: - Remove

    func testRemoveDoesNotMoveOtherBlocks() {
        var world = makeWorld(columns: [(col: 4, height: 4)])
        let removed = world.removeBlock(at: GridCell(col: 4, row: 1))
        XCTAssertNotNil(removed)
        // Nothing falls: the gap at row 1 stays, blocks above keep their rows.
        XCTAssertFalse(world.isOccupied(GridCell(col: 4, row: 1)))
        XCTAssertTrue(world.isOccupied(GridCell(col: 4, row: 2)))
        XCTAssertTrue(world.isOccupied(GridCell(col: 4, row: 3)))
        XCTAssertEqual(world.blocks.count, 3)
    }

    func testRemoveFromEmptyCellReturnsNil() {
        var world = makeWorld()
        XCTAssertNil(world.removeBlock(at: GridCell(col: 0, row: 0)))
    }

    func testRemoveDoesNotAffectOtherColumns() {
        var world = makeWorld(columns: [(col: 1, height: 2), (col: 2, height: 3)])
        world.removeBlock(at: GridCell(col: 1, row: 0))
        XCTAssertFalse(world.isOccupied(GridCell(col: 1, row: 0)))
        XCTAssertTrue(world.isOccupied(GridCell(col: 1, row: 1)))   // stays floating
        XCTAssertEqual(world.blocks.filter { $0.col == 2 }.count, 3)
    }

    // MARK: - Move

    func testMoveBlockToAnyEmptyCell() {
        var world = makeWorld(columns: [(col: 3, height: 2)])
        XCTAssertTrue(world.moveBlock(from: GridCell(col: 3, row: 1),
                                      to: GridCell(col: 8, row: 7)))  // floating destination
        XCTAssertFalse(world.isOccupied(GridCell(col: 3, row: 1)))
        XCTAssertTrue(world.isOccupied(GridCell(col: 8, row: 7)))
    }

    func testMoveBlockKeepsDesignAndCrackedState() {
        var world = makeWorld()
        world.place(designID: "cracked", isCracked: true,
                    at: GridCell(col: 0, row: 0), date: date)
        world.moveBlock(from: GridCell(col: 0, row: 0), to: GridCell(col: 5, row: 9))
        let moved = world.block(at: GridCell(col: 5, row: 9))
        XCTAssertEqual(moved?.designID, "cracked")
        XCTAssertEqual(moved?.isCracked, true)
    }

    func testMoveToOccupiedCellFails() {
        var world = makeWorld(columns: [(col: 3, height: 1), (col: 8, height: 1)])
        XCTAssertFalse(world.moveBlock(from: GridCell(col: 3, row: 0),
                                       to: GridCell(col: 8, row: 0)))
        XCTAssertTrue(world.isOccupied(GridCell(col: 3, row: 0)))
    }

    func testValidMoveDestinationsAreAllOtherEmptyCells() {
        let world = makeWorld(columns: [(col: 6, height: 1)])
        let destinations = world.validMoveDestinations(from: GridCell(col: 6, row: 0))
        // Everything except the source cell (which is the only occupied one).
        XCTAssertEqual(destinations.count, World.columns * World.rows - 1)
        XCTAssertFalse(destinations.contains(GridCell(col: 6, row: 0)))
        XCTAssertTrue(destinations.contains(GridCell(col: 0, row: 0)))
        XCTAssertTrue(destinations.contains(GridCell(col: 0, row: 7)))  // floating ok
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

    // MARK: - Water runs (fish)

    private func placeWater(_ world: inout World, row: Int, cols: [Int]) {
        for c in cols {
            world.place(designID: "water", isCracked: false,
                        at: GridCell(col: c, row: row), date: date)
        }
    }

    func testThreeContiguousWaterFormsARun() {
        var world = makeWorld()
        placeWater(&world, row: 0, cols: [4, 5, 6])
        XCTAssertEqual(world.waterRuns, [BlockRun(row: 0, startCol: 4, endCol: 6)])
    }

    func testTwoWaterIsNotEnough() {
        var world = makeWorld()
        placeWater(&world, row: 0, cols: [4, 5])
        XCTAssertTrue(world.waterRuns.isEmpty)
    }

    func testGapBreaksTheRun() {
        var world = makeWorld()
        placeWater(&world, row: 0, cols: [0, 1, 2, 4, 5]) // gap at col 3
        XCTAssertEqual(world.waterRuns, [BlockRun(row: 0, startCol: 0, endCol: 2)])
    }

    func testWaterRunsArestrictlyPerRow() {
        var world = makeWorld()
        placeWater(&world, row: 0, cols: [0, 1, 2])
        placeWater(&world, row: 3, cols: [0, 1, 2])           // floating row, also qualifies
        placeWater(&world, row: 5, cols: [0, 1])              // too short
        let runs = world.waterRuns
        XCTAssertEqual(runs.count, 2)
        XCTAssertTrue(runs.contains(BlockRun(row: 0, startCol: 0, endCol: 2)))
        XCTAssertTrue(runs.contains(BlockRun(row: 3, startCol: 0, endCol: 2)))
    }

    func testNonWaterBlocksDoNotFormRuns() {
        var world = makeWorld()
        for c in [4, 5, 6] {
            world.place(designID: "glass", isCracked: false,
                        at: GridCell(col: c, row: 0), date: date)
        }
        XCTAssertTrue(world.waterRuns.isEmpty)
    }

    func testGardenRunsAreDetectedSeparately() {
        var world = makeWorld()
        for c in [2, 3, 4] {
            world.place(designID: "garden", isCracked: false,
                        at: GridCell(col: c, row: 0), date: date)
        }
        placeWater(&world, row: 2, cols: [0, 1, 2])
        XCTAssertEqual(world.gardenRuns, [BlockRun(row: 0, startCol: 2, endCol: 4)])
        XCTAssertEqual(world.waterRuns, [BlockRun(row: 2, startCol: 0, endCol: 2)])
        // Garden blocks don't appear in water runs and vice versa.
        XCTAssertFalse(world.gardenRuns.contains(BlockRun(row: 2, startCol: 0, endCol: 2)))
    }

    func testTwoGardenBlocksDoNotFlower() {
        var world = makeWorld()
        for c in [2, 3] {
            world.place(designID: "garden", isCracked: false,
                        at: GridCell(col: c, row: 0), date: date)
        }
        XCTAssertTrue(world.gardenRuns.isEmpty)
    }
}
