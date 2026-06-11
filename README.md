# Pomolego

A native macOS menu bar Pomodoro app where every completed focus session
builds one block in a persistent 2D world. Pick a design, pick the exact
spot on the ground or on top of existing blocks, focus, and watch your
city grow. Abandon a session and a cracked gray block marks the spot.
Think *Forest, but focus LEGO*.

- **Swift 5.9+ / SwiftUI**, minimum macOS 14
- Menu-bar-only (`LSUIElement`), no Dock icon
- No third-party runtime dependencies; all block art is drawn
  programmatically (no image assets)
- **Completely silent** — there is no audio code anywhere in the app

## Build & run

Requirements: Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). The Xcode project is generated from `project.yml`
and is not checked in.

```sh
xcodegen generate
xcodebuild -project Pomolego.xcodeproj -scheme Pomolego -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/Pomolego-*/Build/Products/Debug/Pomolego.app
```

Or open `Pomolego.xcodeproj` in Xcode and hit Run. The app appears in the
menu bar only — look for the small block/skyline icon at the top right.

## Tests

```sh
xcodebuild -project Pomolego.xcodeproj -scheme Pomolego test
```

The test bundle compiles the timer engine and world model directly
(no app host), covering the wall-clock state machine (completion, long-break
cadence, pause/resume, clock changes, sleep, crash restore) and placement
validity (gravity rule, stacking, bounds, default targets).

## How it works

- **Timer** — a wall-clock state machine (`TimerEngine`). Remaining time is
  always `endDate - now`, never accumulated ticks, so it survives sleep and
  clock drift. If a session's deadline passes while the Mac sleeps or the
  app is closed, the session completes on wake/relaunch and the block is
  placed (the celebration shows once).
- **World** — a 28×14 grid; row 0 is the ground. A block may only be placed
  on the ground or directly on top of another block. The world persists
  forever. While idle, clicking an existing block selects it for **moving or
  deleting** (a later change to the original "never deletable" spec rule);
  removing a block lets the column above fall down so nothing floats.
  Settings → Danger Zone can archive the world and start a fresh canvas
  (statistics keep all history).
- **Designs** — 10 designs unlock as your all-time completed block count
  grows (Brick/Glass/Wood from the start; Observatory at 100). The catalog
  is a single data-driven array (`BlockDesign.catalog`) — adding a design is
  one entry plus one drawing case.
- **Data** — JSON under `~/Library/Application Support/Pomolego/`
  (`world.json`, `sessions.json`, `running.json`), written atomically.
  All statistics derive from the append-only session log.

## Decisions made while implementing the spec

- **Name**: the spec said "rename freely"; the app is **Pomolego** to match
  the repository (Pomodoro + LEGO).
- **Valid-cell highlighting** is always visible whenever placement is
  possible (idle and during focus) instead of a separate "Choose spot"
  mode — fewer clicks, same behaviors (stacking and side-by-side ground
  placement). Tapping a highlighted cell sets/moves the dashed ghost target.
- **Skipping a long break also resets** the consecutive-session counter;
  otherwise the very next session would immediately propose another long
  break.
- **Pausing during a break** is supported, matching focus sessions.
- "End break" early counts the break as taken (it resets the long-break
  cycle when it was a long break).
- The menu bar icon is a LEGO-style brick with studs: template-rendered
  when idle, tinted in the active design's color during a focus session
  (a skyline silhouette was tried first but was unreadable at 16 pt).
- No app sandbox/hardened runtime for the v1 dev build (ad-hoc signed,
  local use).

## Future ideas (out of scope for v1)

- iCloud sync
- Sounds of any kind (intentionally absent today)
- Themed design packs / seasons
- Export the world as a PNG to share
- Weekly canvases
- Repairing cracked blocks by completing the next session
- iOS companion
