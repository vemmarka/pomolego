# Pomolego

A native macOS menu bar Pomodoro app where every completed focus session
builds one block in a persistent 2D world. Pick the exact spot on the ground or on top of existing blocks, focus, and watch your
city grow. Abandon a session and a cracked gray block marks the spot.
Think *Pomodoro + LEGO*.

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
- **World** — a 28×14 grid. Placement is **free**: a block can go in any
  empty cell anywhere on the grid, floating or stacked — there is no gravity
  or support requirement (a later change from the original spec's gravity
  rule). The world persists forever. While idle, clicking an existing block
  selects it for **moving or deleting** (also a change from the original
  "never deletable" rule); removing a block leaves everything else in place.
  Settings → Danger Zone can archive the world and start a fresh canvas
  (statistics keep all history).
- **Designs** — 19 designs unlock as your all-time completed block count
  grows: Brick/Glass/Wood from the start, then Garden (3), Stone (6),
  Sandstone (10), Water (12), Blossom (14), Neon (19), Coral (25),
  Greenhouse (32), Bookshelf (40), Marble (48), Circuit (57), Lava (67),
  Gold (78), Clockwork (90), Observatory (105), Moon (120). The catalog is
  a single data-driven array (`BlockDesign.catalog`) — adding a design is
  one entry plus one drawing case.
- **Data** — JSON under `~/Library/Application Support/Pomolego/`
  (`world.json`, `sessions.json`, `running.json`), written atomically.
  All statistics derive from the append-only session log.

## Decisions made while implementing the spec

- **Name**: the spec said "rename freely"; the app is **Pomolego** to match
  the repository (Pomodoro + LEGO).
- **Valid-cell highlighting** is always visible whenever placement is
  possible (idle and during focus) instead of a separate "Choose spot"
  mode — fewer clicks. With free placement this renders as a faint grid over
  the empty cells. Tapping a cell sets/moves the dashed ghost target.
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

## Web version

`docs/` contains a standalone web version of Pomolego — same world, designs,
unlocks, timer, breaks, editing, settings, statistics, and a silent completion
animation. It is a static site (HTML + CSS + vanilla JS modules, all block art
drawn on `<canvas>`), with **no build step and no dependencies**. State is saved
in the browser via `localStorage` (the web equivalent of the native app's local
files), including resuming a running timer after a refresh or tab close. The
countdown shows in the browser tab title and favicon — the web stand-in for the
menu bar.

Run it locally with any static server:

```sh
cd docs
python3 -m http.server 8765
# open http://localhost:8765
```

(Opening `index.html` directly via `file://` won't work because it uses ES
modules — use a local server, or just visit the deployed site.)

### Deploying to pomolego.vemmarka.com (GitHub Pages)

The web app is served from `docs/` on the `main` branch. `docs/CNAME` already
pins the custom domain. Two one-time manual steps:

1. **Enable Pages** — in the GitHub repo: Settings → Pages → "Build and
   deployment" → Source: *Deploy from a branch* → Branch: `main`, folder:
   `/docs` → Save. GitHub will show the custom domain `pomolego.vemmarka.com`
   (read from the CNAME file) and, once DNS resolves, offer "Enforce HTTPS".
2. **Add a DNS record** — wherever vemmarka.com's DNS is managed, add a CNAME
   record: host/name `pomolego`, value `vemmarka.github.io` (your GitHub
   username + `.github.io`). DNS can take from minutes to a few hours to
   propagate.

After both, the site is live at https://pomolego.vemmarka.com. Pushing to
`main` redeploys automatically.

## Future ideas (out of scope for v1)

- iCloud sync
- Sounds of any kind (intentionally absent today)
- Themed design packs / seasons
- Export the world as a PNG to share
- Weekly canvases
- Repairing cracked blocks by completing the next session
- iOS companion
