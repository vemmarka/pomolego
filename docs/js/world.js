// The persistent 2D block world — mirrors Models/World.swift.
// Row 0 is the ground (bottom); rows grow upward.

export const COLUMNS = 28;
export const ROWS = 14;

export function cellKey(col, row) {
  return `${col},${row}`;
}

// A world is { blocks: [{ id, col, row, designID, isCracked, placedAt }] }.
export function emptyWorld() {
  return { blocks: [] };
}

function occupancy(world) {
  const set = new Set();
  for (const b of world.blocks) set.add(cellKey(b.col, b.row));
  return set;
}

export function blockAt(world, col, row) {
  return world.blocks.find((b) => b.col === col && b.row === row) || null;
}

export function isOccupied(world, col, row) {
  return blockAt(world, col, row) !== null;
}

export function inBounds(col, row) {
  return col >= 0 && col < COLUMNS && row >= 0 && row < ROWS;
}

// Free placement: any in-bounds, unoccupied cell is valid. Blocks may float
// anywhere on the grid — there is no gravity/support requirement.
export function isValidPlacement(world, col, row) {
  return inBounds(col, row) && !isOccupied(world, col, row);
}

// Every empty cell on the grid.
export function validCells(world) {
  const occ = occupancy(world);
  const result = [];
  for (let col = 0; col < COLUMNS; col++) {
    for (let row = 0; row < ROWS; row++) {
      if (!occ.has(cellKey(col, row))) result.push({ col, row });
    }
  }
  return result;
}

// Highest occupied row (+1) in a column — used only for the idle skyline-ish
// glyph. With free placement this is just "tallest filled row".
export function columnHeight(world, col) {
  const rows = world.blocks.filter((b) => b.col === col).map((b) => b.row);
  return rows.length ? Math.max(...rows) + 1 : 0;
}

export function mostRecentBlock(world) {
  let best = null;
  for (const b of world.blocks) {
    if (!best || b.placedAt > best.placedAt) best = b;
  }
  return best;
}

export function nearestValidGroundCell(world, col) {
  const ground = validCells(world).filter((c) => c.row === 0);
  if (ground.length === 0) return null;
  return ground.reduce((a, b) => (Math.abs(a.col - col) <= Math.abs(b.col - col) ? a : b));
}

// Default target when the user starts without picking a spot: directly above
// the most recently placed block (natural stacking) if free, else a free cell
// near the bottom-center.
export function defaultTarget(world) {
  const recent = mostRecentBlock(world);
  if (recent && isValidPlacement(world, recent.col, recent.row + 1)) {
    return { col: recent.col, row: recent.row + 1 };
  }
  return nearestValidGroundCell(world, Math.floor(COLUMNS / 2)) || validCells(world)[0] || null;
}

export function placeBlock(world, { designID, isCracked, col, row, placedAt }) {
  if (!isValidPlacement(world, col, row)) return false;
  world.blocks.push({
    id: crypto.randomUUID(),
    col, row, designID, isCracked, placedAt,
  });
  return true;
}

// Remove a block. With free placement nothing falls — other blocks stay put.
export function removeBlock(world, col, row) {
  const index = world.blocks.findIndex((b) => b.col === col && b.row === row);
  if (index < 0) return null;
  return world.blocks.splice(index, 1)[0];
}

// Any other empty cell is a valid move destination.
export function validMoveDestinations(world, col, row) {
  if (!isOccupied(world, col, row)) return [];
  return validCells(world).filter((c) => !(c.col === col && c.row === row));
}

export function moveBlock(world, from, to) {
  if (from.col === to.col && from.row === to.row) return false;
  const block = blockAt(world, from.col, from.row);
  if (!block || !isValidPlacement(world, to.col, to.row)) return false;
  removeBlock(world, from.col, from.row);
  world.blocks.push({ ...block, col: to.col, row: to.row });
  return true;
}

export function cloneWorld(world) {
  return { blocks: world.blocks.map((b) => ({ ...b })) };
}

export function builtCount(world) {
  return world.blocks.filter((b) => !b.isCracked).length;
}

export function crackedCount(world) {
  return world.blocks.filter((b) => b.isCracked).length;
}
