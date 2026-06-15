// Block design catalog — mirrors Sources/Pomolego/Models/BlockDesign.swift.
// Colors are stored as 0–255 RGB so they match the native app exactly.

function rgb(r, g, b) {
  return { r: Math.round(r * 255), g: Math.round(g * 255), b: Math.round(b * 255) };
}

export function css(color, alpha = 1) {
  return alpha === 1
    ? `rgb(${color.r}, ${color.g}, ${color.b})`
    : `rgba(${color.r}, ${color.g}, ${color.b}, ${alpha})`;
}

// App-wide accent: warm terracotta.
export const APP_ACCENT = rgb(0.80, 0.38, 0.28);

export const CATALOG = [
  { id: 'brick',       name: 'Brick',       unlockAt: 0,   base: rgb(0.76, 0.38, 0.28), accent: rgb(0.88, 0.80, 0.72) },
  { id: 'glass',       name: 'Glass',       unlockAt: 0,   base: rgb(0.36, 0.58, 0.82), accent: rgb(0.80, 0.90, 1.00) },
  { id: 'wood',        name: 'Wood',        unlockAt: 0,   base: rgb(0.72, 0.53, 0.32), accent: rgb(0.50, 0.34, 0.18) },
  { id: 'garden',      name: 'Garden',      unlockAt: 3,   base: rgb(0.38, 0.62, 0.34), accent: rgb(0.22, 0.44, 0.20) },
  { id: 'stone',       name: 'Stone',       unlockAt: 6,   base: rgb(0.58, 0.58, 0.60), accent: rgb(0.40, 0.40, 0.42) },
  { id: 'sandstone',   name: 'Sandstone',   unlockAt: 10,  base: rgb(0.85, 0.74, 0.55), accent: rgb(0.64, 0.51, 0.33) },
  { id: 'water',       name: 'Water',       unlockAt: 12,  base: rgb(0.30, 0.58, 0.78), accent: rgb(0.70, 0.88, 0.98) },
  { id: 'blossom',     name: 'Blossom',     unlockAt: 14,  base: rgb(0.93, 0.76, 0.81), accent: rgb(0.62, 0.36, 0.32) },
  { id: 'neon',        name: 'Neon',        unlockAt: 19,  base: rgb(0.45, 0.20, 0.65), accent: rgb(0.95, 0.45, 1.00) },
  { id: 'coral',       name: 'Coral',       unlockAt: 25,  base: rgb(0.93, 0.55, 0.48), accent: rgb(1.00, 0.82, 0.74) },
  { id: 'greenhouse',  name: 'Greenhouse',  unlockAt: 32,  base: rgb(0.25, 0.62, 0.60), accent: rgb(0.12, 0.38, 0.30) },
  { id: 'bookshelf',   name: 'Bookshelf',   unlockAt: 40,  base: rgb(0.52, 0.36, 0.24), accent: rgb(0.84, 0.70, 0.52) },
  { id: 'marble',      name: 'Marble',      unlockAt: 48,  base: rgb(0.92, 0.92, 0.94), accent: rgb(0.65, 0.66, 0.72) },
  { id: 'circuit',     name: 'Circuit',     unlockAt: 57,  base: rgb(0.10, 0.32, 0.22), accent: rgb(0.45, 0.85, 0.55) },
  { id: 'lava',        name: 'Lava',        unlockAt: 67,  base: rgb(0.17, 0.12, 0.11), accent: rgb(1.00, 0.45, 0.15) },
  { id: 'gold',        name: 'Gold',        unlockAt: 78,  base: rgb(0.88, 0.72, 0.25), accent: rgb(1.00, 0.90, 0.55) },
  { id: 'clockwork',   name: 'Clockwork',   unlockAt: 90,  base: rgb(0.56, 0.42, 0.27), accent: rgb(0.90, 0.74, 0.46) },
  { id: 'observatory', name: 'Observatory', unlockAt: 105, base: rgb(0.18, 0.20, 0.32), accent: rgb(0.75, 0.80, 0.95) },
  { id: 'moon',        name: 'Moon',        unlockAt: 120, base: rgb(0.10, 0.11, 0.18), accent: rgb(0.86, 0.87, 0.80) },
];

// Fixed style for abandoned sessions: never in the picker, never counts
// toward unlocks.
export const CRACKED = {
  id: 'cracked', name: 'Cracked', unlockAt: Infinity,
  base: rgb(0.55, 0.55, 0.55), accent: rgb(0.30, 0.30, 0.30),
};

export function designForId(id) {
  if (id === CRACKED.id) return CRACKED;
  return CATALOG.find((d) => d.id === id) || CATALOG[0];
}

export function unlockedDesigns(totalBlocksBuilt) {
  return CATALOG.filter((d) => d.unlockAt <= totalBlocksBuilt);
}

export function newlyUnlocked(before, after) {
  return CATALOG.filter((d) => d.unlockAt > before && d.unlockAt <= after);
}

export function nextUnlock(totalBlocksBuilt) {
  return CATALOG
    .filter((d) => d.unlockAt > totalBlocksBuilt)
    .sort((a, b) => a.unlockAt - b.unlockAt)[0] || null;
}
