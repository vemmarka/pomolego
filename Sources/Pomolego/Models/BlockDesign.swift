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
        BlockDesign(id: "garden", name: "Garden", unlockAt: 3,
                    baseColor: Color(red: 0.38, green: 0.62, blue: 0.34),
                    accentColor: Color(red: 0.22, green: 0.44, blue: 0.20)),
        BlockDesign(id: "stone", name: "Stone", unlockAt: 6,
                    baseColor: Color(red: 0.58, green: 0.58, blue: 0.60),
                    accentColor: Color(red: 0.40, green: 0.40, blue: 0.42)),
        BlockDesign(id: "sandstone", name: "Sandstone", unlockAt: 10,
                    baseColor: Color(red: 0.85, green: 0.74, blue: 0.55),
                    accentColor: Color(red: 0.64, green: 0.51, blue: 0.33)),
        BlockDesign(id: "water", name: "Water", unlockAt: 12,
                    baseColor: Color(red: 0.30, green: 0.58, blue: 0.78),
                    accentColor: Color(red: 0.70, green: 0.88, blue: 0.98)),
        BlockDesign(id: "blossom", name: "Blossom", unlockAt: 14,
                    baseColor: Color(red: 0.93, green: 0.76, blue: 0.81),
                    accentColor: Color(red: 0.62, green: 0.36, blue: 0.32)),
        BlockDesign(id: "neon", name: "Neon", unlockAt: 19,
                    baseColor: Color(red: 0.45, green: 0.20, blue: 0.65),
                    accentColor: Color(red: 0.95, green: 0.45, blue: 1.0)),
        BlockDesign(id: "coral", name: "Coral", unlockAt: 25,
                    baseColor: Color(red: 0.93, green: 0.55, blue: 0.48),
                    accentColor: Color(red: 1.0, green: 0.82, blue: 0.74)),
        BlockDesign(id: "greenhouse", name: "Greenhouse", unlockAt: 32,
                    baseColor: Color(red: 0.25, green: 0.62, blue: 0.60),
                    accentColor: Color(red: 0.12, green: 0.38, blue: 0.30)),
        BlockDesign(id: "bookshelf", name: "Bookshelf", unlockAt: 40,
                    baseColor: Color(red: 0.52, green: 0.36, blue: 0.24),
                    accentColor: Color(red: 0.84, green: 0.70, blue: 0.52)),
        BlockDesign(id: "marble", name: "Marble", unlockAt: 48,
                    baseColor: Color(red: 0.92, green: 0.92, blue: 0.94),
                    accentColor: Color(red: 0.65, green: 0.66, blue: 0.72)),
        BlockDesign(id: "circuit", name: "Circuit", unlockAt: 57,
                    baseColor: Color(red: 0.10, green: 0.32, blue: 0.22),
                    accentColor: Color(red: 0.45, green: 0.85, blue: 0.55)),
        BlockDesign(id: "lava", name: "Lava", unlockAt: 67,
                    baseColor: Color(red: 0.17, green: 0.12, blue: 0.11),
                    accentColor: Color(red: 1.0, green: 0.45, blue: 0.15)),
        BlockDesign(id: "gold", name: "Gold", unlockAt: 78,
                    baseColor: Color(red: 0.88, green: 0.72, blue: 0.25),
                    accentColor: Color(red: 1.0, green: 0.90, blue: 0.55)),
        BlockDesign(id: "clockwork", name: "Clockwork", unlockAt: 90,
                    baseColor: Color(red: 0.56, green: 0.42, blue: 0.27),
                    accentColor: Color(red: 0.90, green: 0.74, blue: 0.46)),
        BlockDesign(id: "observatory", name: "Observatory", unlockAt: 105,
                    baseColor: Color(red: 0.18, green: 0.20, blue: 0.32),
                    accentColor: Color(red: 0.75, green: 0.80, blue: 0.95)),
        BlockDesign(id: "moon", name: "Moon", unlockAt: 120,
                    baseColor: Color(red: 0.10, green: 0.11, blue: 0.18),
                    accentColor: Color(red: 0.86, green: 0.87, blue: 0.80)),
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
