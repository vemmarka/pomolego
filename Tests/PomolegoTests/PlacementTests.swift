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
