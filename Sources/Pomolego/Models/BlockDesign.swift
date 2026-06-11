import SwiftUI

/// One buildable block design. The catalog below is the single source of
/// truth — adding a design later means appending one entry and one drawing
/// case in BlockArt.
struct BlockDesign: Identifiable, Equatable {
    let id: String
    let name: String
    let unlockAt: Int
    let baseColor: Color
    let accentColor: Color

    static let catalog: [BlockDesign] = [
        BlockDesign(id: "brick", name: "Brick", unlockAt: 0,
                    baseColor: Color(red: 0.76, green: 0.38, blue: 0.28),
                    accentColor: Color(red: 0.88, green: 0.80, blue: 0.72)),
        BlockDesign(id: "glass", name: "Glass", unlockAt: 0,
                    baseColor: Color(red: 0.36, green: 0.58, blue: 0.82),
                    accentColor: Color(red: 0.80, green: 0.90, blue: 1.0)),
        BlockDesign(id: "wood", name: "Wood", unlockAt: 0,
                    baseColor: Color(red: 0.72, green: 0.53, blue: 0.32),
                    accentColor: Color(red: 0.50, green: 0.34, blue: 0.18)),
        BlockDesign(id: "garden", name: "Garden", unlockAt: 5,
                    baseColor: Color(red: 0.38, green: 0.62, blue: 0.34),
                    accentColor: Color(red: 0.22, green: 0.44, blue: 0.20)),
        BlockDesign(id: "stone", name: "Stone", unlockAt: 10,
                    baseColor: Color(red: 0.58, green: 0.58, blue: 0.60),
                    accentColor: Color(red: 0.40, green: 0.40, blue: 0.42)),
        BlockDesign(id: "neon", name: "Neon", unlockAt: 20,
                    baseColor: Color(red: 0.45, green: 0.20, blue: 0.65),
                    accentColor: Color(red: 0.95, green: 0.45, blue: 1.0)),
        BlockDesign(id: "greenhouse", name: "Greenhouse", unlockAt: 35,
                    baseColor: Color(red: 0.25, green: 0.62, blue: 0.60),
                    accentColor: Color(red: 0.12, green: 0.38, blue: 0.30)),
        BlockDesign(id: "marble", name: "Marble", unlockAt: 50,
                    baseColor: Color(red: 0.92, green: 0.92, blue: 0.94),
                    accentColor: Color(red: 0.65, green: 0.66, blue: 0.72)),
        BlockDesign(id: "gold", name: "Gold", unlockAt: 75,
                    baseColor: Color(red: 0.88, green: 0.72, blue: 0.25),
                    accentColor: Color(red: 1.0, green: 0.90, blue: 0.55)),
        BlockDesign(id: "observatory", name: "Observatory", unlockAt: 100,
                    baseColor: Color(red: 0.18, green: 0.20, blue: 0.32),
                    accentColor: Color(red: 0.75, green: 0.80, blue: 0.95)),
    ]

    /// Fixed style for abandoned sessions. Never appears in the picker and
    /// never counts toward unlocks.
    static let cracked = BlockDesign(id: "cracked", name: "Cracked", unlockAt: .max,
                                     baseColor: Color(red: 0.55, green: 0.55, blue: 0.55),
                                     accentColor: Color(red: 0.30, green: 0.30, blue: 0.30))

    static func design(for id: String) -> BlockDesign {
        if id == cracked.id { return cracked }
        return catalog.first { $0.id == id } ?? catalog[0]
    }

    static func unlocked(totalBlocksBuilt: Int) -> [BlockDesign] {
        catalog.filter { $0.unlockAt <= totalBlocksBuilt }
    }

    /// The design (if any) whose threshold is crossed when the total goes
    /// from `before` to `after` completed blocks.
    static func newlyUnlocked(before: Int, after: Int) -> [BlockDesign] {
        catalog.filter { $0.unlockAt > before && $0.unlockAt <= after }
    }

    static func nextUnlock(totalBlocksBuilt: Int) -> BlockDesign? {
        catalog.filter { $0.unlockAt > totalBlocksBuilt }.min(by: { $0.unlockAt < $1.unlockAt })
    }
}
