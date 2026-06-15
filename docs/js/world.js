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

// Gravity rule: a block may sit on the ground row or directly on top of an
// occupied cell. No floating blocks.
export function isValidPlacement(world, col, row) {
  if (!inBounds(col, row) || isOccupied(world, col, row)) return false;
  if (row === 0) return true;
  return isOccupied(world, col, row - 1);
}

// Exactly one valid cell per column: the lowest unoccupied cell whose
// support exists (ground or top of the column's stack).
export function validCells(world) {
  const occ = occupancy(world);
  const result = [];
  for (let col = 0; col < COLUMNS; col++) {
    let row = 0;
    while (occ.has(cellKey(col, row))) row++;
    if (inBounds(col, row)) result.push({ col, row });
  }
  return result;
}

export function columnHeight(world, col) {
  let row = 0;
  while (isOccupied(world, col, row)) row++;
  return row;
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

// Default target when the user starts without picking a spot.
export function defaultTarget(world) {
  const recent = mostRecentBlock(world);
  if (recent) {
    const above = { col: recent.col, row: columnHeight(world, recent.col) };
    if (isValidPlacement(world, above.col, above.row)) return above;
    return nearestValidGroundCell(world, recent.col);
  }
  return nearestValidGroundCell(world, Math.floor(COLUMNS / 2));
}

export function placeBlock(world, { designID, isCracked, col, row, placedAt }) {
  if (!isValidPlacement(world, col, row)) return false;
  world.blocks.push({
    id: crypto.randomUUID(),
    col, row, designID, isCracked, placedAt,
  });
  return true;
}

// Remove a block; everything above it in the column falls one row so the
// gravity invariant is preserved.
export function removeBlock(world, col, row) {
  const index = world.blocks.findIndex((b) => b.col === col && b.row === row);
  if (index < 0) return null;
  const [removed] = world.blocks.splice(index, 1);
  for (const b of world.blocks) {
    if (b.col === col && b.row > row) b.row -= 1;
  }
  return removed;
}

export function validMoveDestinations(world, col, row) {
  if (!isOccupied(world, col, row)) return [];
  const clone = cloneWorld(world);
  removeBlock(clone, col, row);
  return validCells(clone).filter((c) => !(c.col === col && c.row === row));
}

export function moveBlock(world, from, to) {
  if (from.col === to.col && from.row === to.row) return false;
  const block = blockAt(world, from.col, from.row);
  if (!block) return false;
  const clone = cloneWorld(world);
  removeBlock(clone, from.col, from.row);
  if (!isValidPlacement(clone, to.col, to.row)) return false;
  // Apply to the clone, then adopt it.
  const moved = { ...block, col: to.col, row: to.row };
  clone.blocks.push(moved);
  world.blocks = clone.blocks;
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
