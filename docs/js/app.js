// Pomolego web app — orchestrator and UI. Mirrors AppState + the SwiftUI
// views from the native macOS app. State persists in localStorage; a running
// timer resumes after a refresh or tab close.

import { CATALOG, designForId, css, APP_ACCENT, unlockedDesigns, newlyUnlocked } from './designs.js';
import { drawBlock } from './art.js';
import * as W from './world.js';
import { TimerEngine, countdownString } from './timer.js';
import { Store } from './store.js';
import { computeStats } from './stats.js';

const CELL_W = 24;
const CELL_H = 18;
const DPR = Math.min(window.devicePixelRatio || 1, 2);
const MIN_FOCUS_MINUTES = 5;
const MAX_FOCUS_MINUTES = 180;
const CANCEL_GRACE_MS = 5000; // consequence-free cancel window after starting focus

const engine = new TimerEngine();
let settings = Store.loadSettings();
let worldFile = Store.loadWorldFile();
let sessions = Store.loadSessions();
let selectedDesignID = settings.selectedDesignID;
let focusMinutes = Math.min(MAX_FOCUS_MINUTES, Math.max(MIN_FOCUS_MINUTES, settings.focusMinutes));
settings.focusMinutes = focusMinutes; // clamp any previously-saved sub-5 value
let targetCell = null;
let editMode = { kind: 'none' }; // none | { kind:'selected', cell } | { kind:'moving', cell }
let unlockAnnouncement = null;
let currentSessionStart = null;
let overlayTimeout = null;

const world = () => worldFile.current;
const totalBlocksBuilt = () => sessions.filter((s) => s.kind === 'focus' && s.outcome === 'completed').length;

// --- DOM refs ------------------------------------------------------------
const $ = (id) => document.getElementById(id);
const canvas = $('world-canvas');
const ctx = canvas.getContext('2d');
const controlsEl = $('controls');

// --- lifecycle -----------------------------------------------------------

function init() {
  sizeCanvas();
  restoreRunningState();
  wireStaticButtons();
  if (!targetCell && engine.phase.kind === 'idle') targetCell = W.defaultTarget(world());
  render();
  setInterval(tick, 1000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) tick(); });
  window.addEventListener('focus', tick);
}

function tick() {
  engine.config = {
    sessionsBeforeLongBreak: settings.sessionsBeforeLongBreak,
    idleResetGap: settings.idleResetMinutes * 60000,
  };
  const event = engine.tick();
  if (event) handleEvent(event);
  updateTimerChrome();
  // Redraw only the canvas each second (cheap); full re-render on transitions.
  drawWorld();
}

function handleEvent(event) {
  if (event.type === 'focusCompleted') {
    completeFocusSession();
  } else if (event.type === 'breakEnded') {
    logSession({ kind: event.breakKind === 'long' ? 'longBreak' : 'shortBreak', outcome: 'completed' });
    showOverlay({ type: 'breakOver' });
    if (settings.autoStartNextFocus) startFocus();
  }
  persistRunning();
  render();
}

// --- core transitions ----------------------------------------------------

function completeFocusSession() {
  const before = totalBlocksBuilt();
  const cell = effectiveTarget();
  if (cell) {
    W.placeBlock(world(), { designID: selectedDesignID, isCracked: false, col: cell.col, row: cell.row, placedAt: Date.now() });
    Store.saveWorldFile(worldFile);
  }
  logSession({ kind: 'focus', outcome: 'completed', designID: selectedDesignID, cell });
  targetCell = null;

  const justUnlocked = newlyUnlocked(before, totalBlocksBuilt())[0];
  if (justUnlocked) unlockAnnouncement = justUnlocked;

  showOverlay({ type: 'blockBuilt', design: designForId(selectedDesignID) });

  if (settings.autoStartBreaks && engine.phase.kind === 'breakPrompt') startBreak();
}

function effectiveTarget() {
  if (targetCell && W.isValidPlacement(world(), targetCell.col, targetCell.row)) return targetCell;
  return W.defaultTarget(world());
}

function startFocus() {
  if (engine.phase.kind !== 'idle') return;
  editMode = { kind: 'none' };
  currentSessionStart = Date.now();
  engine.startFocus(focusMinutes * 60000);
  if (!targetCell) targetCell = W.defaultTarget(world());
  afterTransition();
  // Re-render once the grace window closes so the Cancel button becomes Abandon.
  setTimeout(() => { if (engine.isFocus()) render(); }, CANCEL_GRACE_MS + 50);
}

function pause() { engine.pause(); afterTransition(); }
function resume() { engine.resume(); afterTransition(); }

// Within CANCEL_GRACE_MS of starting, a focus session can be cancelled cleanly.
function isInCancelGrace() {
  return engine.isFocus() && currentSessionStart != null
    && Date.now() - currentSessionStart < CANCEL_GRACE_MS;
}

// Discard a just-started focus session with no consequences (no cracked
// block, no logged session).
function cancelFocus() {
  if (!engine.isFocus()) return;
  engine.abandonFocus();
  afterTransition();
}

function abandonFocus() {
  if (!engine.isFocus()) return;
  const cell = effectiveTarget();
  if (settings.crackedBlockOnAbandon && cell) {
    W.placeBlock(world(), { designID: 'cracked', isCracked: true, col: cell.col, row: cell.row, placedAt: Date.now() });
    Store.saveWorldFile(worldFile);
  }
  engine.abandonFocus();
  logSession({ kind: 'focus', outcome: 'abandoned', designID: selectedDesignID, cell: settings.crackedBlockOnAbandon ? cell : null });
  targetCell = null;
  afterTransition();
}

function startBreak() {
  if (engine.phase.kind !== 'breakPrompt') return;
  currentSessionStart = Date.now();
  const minutes = engine.phase.breakKind === 'long' ? settings.longBreakMinutes : settings.shortBreakMinutes;
  engine.startBreak(minutes * 60000);
  afterTransition();
}

function skipBreak() {
  if (engine.phase.kind !== 'breakPrompt') return;
  const breakKind = engine.phase.breakKind;
  engine.skipBreak();
  logSession({ kind: breakKind === 'long' ? 'longBreak' : 'shortBreak', outcome: 'skipped' });
  afterTransition();
}

function endBreakEarly() {
  if (!engine.isBreak()) return;
  const breakKind = engine.phase.breakKind;
  engine.endBreakEarly();
  logSession({ kind: breakKind === 'long' ? 'longBreak' : 'shortBreak', outcome: 'completed' });
  afterTransition();
}

function selectDesign(design) {
  if (design.unlockAt > totalBlocksBuilt()) return;
  selectedDesignID = design.id;
  settings.selectedDesignID = design.id;
  Store.saveSettings(settings);
  render();
}

function setFocusMinutes(value) {
  focusMinutes = Math.min(MAX_FOCUS_MINUTES, Math.max(MIN_FOCUS_MINUTES, value));
  settings.focusMinutes = focusMinutes;
  Store.saveSettings(settings);
  render();
}

function startFreshCanvas() {
  if (world().blocks.length === 0) return;
  worldFile.archived.push({ archivedAt: Date.now(), blocks: world().blocks });
  worldFile.current = W.emptyWorld();
  targetCell = null;
  editMode = { kind: 'none' };
  Store.saveWorldFile(worldFile);
  render();
}

function afterTransition() {
  persistRunning();
  updateTimerChrome();
  render();
}

// --- world interaction ---------------------------------------------------

function handleWorldTap(col, row) {
  const phase = engine.phase.kind;
  if (phase === 'focusRunning' || phase === 'focusPaused') {
    if (W.isValidPlacement(world(), col, row)) { targetCell = { col, row }; render(); }
    return;
  }
  if (phase !== 'idle') return;
  handleIdleTap(col, row);
}

function handleIdleTap(col, row) {
  if (editMode.kind === 'moving') {
    const dests = W.validMoveDestinations(world(), editMode.cell.col, editMode.cell.row);
    if (dests.some((c) => c.col === col && c.row === row)) {
      W.moveBlock(world(), editMode.cell, { col, row });
      Store.saveWorldFile(worldFile);
      editMode = { kind: 'none' };
      targetCell = null;
    } else if (W.isOccupied(world(), col, row) && !(col === editMode.cell.col && row === editMode.cell.row)) {
      editMode = { kind: 'selected', cell: { col, row } };
    } else {
      editMode = { kind: 'none' };
    }
    render();
    return;
  }
  if (W.isOccupied(world(), col, row)) {
    const same = editMode.kind === 'selected' && editMode.cell.col === col && editMode.cell.row === row;
    editMode = same ? { kind: 'none' } : { kind: 'selected', cell: { col, row } };
  } else if (W.isValidPlacement(world(), col, row)) {
    editMode = { kind: 'none' };
    targetCell = { col, row };
  }
  render();
}

function selectedBlock() {
  if (editMode.kind === 'selected' || editMode.kind === 'moving') {
    return W.blockAt(world(), editMode.cell.col, editMode.cell.row);
  }
  return null;
}

// --- logging & persistence ----------------------------------------------

function logSession({ kind, outcome, designID = null, cell = null }) {
  sessions.push({
    id: crypto.randomUUID(),
    startedAt: currentSessionStart || Date.now(),
    endedAt: Date.now(),
    plannedDuration: engine.plannedDuration,
    kind, outcome, designID, cell,
  });
  Store.saveSessions(sessions);
  currentSessionStart = null;
}

function persistRunning() {
  if (engine.phase.kind === 'idle') {
    Store.saveRunning(null);
    return;
  }
  Store.saveRunning({
    phase: engine.phase,
    plannedDuration: engine.plannedDuration,
    completedSinceLongBreak: engine.completedSinceLongBreak,
    lastFocusEndedAt: engine.lastFocusEndedAt,
    startedAt: currentSessionStart,
    designID: selectedDesignID,
    targetCell,
  });
}

function restoreRunningState() {
  const saved = Store.loadRunning();
  if (!saved) return;
  currentSessionStart = saved.startedAt;
  if (saved.designID) selectedDesignID = saved.designID;
  targetCell = saved.targetCell;
  engine.restore({
    phase: saved.phase,
    plannedDuration: saved.plannedDuration,
    completedSinceLongBreak: saved.completedSinceLongBreak,
    lastFocusEndedAt: saved.lastFocusEndedAt,
  });
  // If a deadline passed while the tab was closed, the first tick completes
  // the session and shows the overlay exactly once.
  const event = engine.tick();
  if (event) handleEvent(event);
}

// --- rendering: top-level ------------------------------------------------

function render() {
  drawWorld();
  renderUnlockBanner();
  renderControls();
  updateTimerChrome();
  ensureAmbientLoop();
}

function wireStaticButtons() {
  $('btn-stats').onclick = openStats;
  $('btn-settings').onclick = openSettings;
  $('unlock-dismiss').onclick = () => { unlockAnnouncement = null; renderUnlockBanner(); };
  document.querySelectorAll('[data-close-modal]').forEach((b) => {
    b.onclick = () => { $('settings-modal').hidden = true; $('stats-modal').hidden = true; };
  });
  canvas.addEventListener('click', (e) => {
    const rect = canvas.getBoundingClientRect();
    const x = (e.clientX - rect.left);
    const y = (e.clientY - rect.top);
    const col = Math.floor(x / CELL_W);
    const rowFromTop = Math.floor(y / CELL_H);
    const row = W.ROWS - 1 - rowFromTop;
    if (col >= 0 && col < W.COLUMNS && row >= 0 && row < W.ROWS) handleWorldTap(col, row);
  });
}

// --- rendering: world canvas ---------------------------------------------

function sizeCanvas() {
  const w = W.COLUMNS * CELL_W;
  const h = W.ROWS * CELL_H;
  canvas.width = w * DPR;
  canvas.height = h * DPR;
  canvas.style.width = w + 'px';
  canvas.style.height = h + 'px';
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
}

function cellRect(col, row) {
  return {
    x: col * CELL_W,
    y: (W.ROWS - 1 - row) * CELL_H,
    w: CELL_W,
    h: CELL_H,
  };
}

function roundRect(c, x, y, w, h, r) {
  const radius = Math.min(r, w / 2, h / 2);
  c.beginPath();
  c.moveTo(x + radius, y);
  c.arcTo(x + w, y, x + w, y + h, radius);
  c.arcTo(x + w, y + h, x, y + h, radius);
  c.arcTo(x, y + h, x, y, radius);
  c.arcTo(x, y, x + w, y, radius);
  c.closePath();
}

function drawWorld() {
  const w = W.COLUMNS * CELL_W;
  const h = W.ROWS * CELL_H;
  ctx.clearRect(0, 0, w, h);

  // Ground line.
  ctx.strokeStyle = 'rgba(127,127,127,0.35)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(0, h - 0.5);
  ctx.lineTo(w, h - 0.5);
  ctx.stroke();

  for (const b of world().blocks) {
    const r = cellRect(b.col, b.row);
    drawBlock(ctx, r.x, r.y, r.w, r.h, b.designID, b.isCracked);
  }

  const phase = engine.phase.kind;
  const canPlace = phase === 'idle' || phase === 'focusRunning' || phase === 'focusPaused';

  if (editMode.kind === 'moving') {
    drawMoveDestinations(editMode.cell);
  } else if (canPlace) {
    drawValidCells();
    if (editMode.kind === 'none') drawGhost();
  }
  drawSelection();
  drawInProgress();
  drawFish(performance.now() / 1000);
  drawFlowers(performance.now() / 1000);
}

function drawValidCells() {
  ctx.strokeStyle = 'rgba(127,127,127,0.12)';
  ctx.lineWidth = 1;
  for (const c of W.validCells(world())) {
    if (targetCell && c.col === targetCell.col && c.row === targetCell.row) continue;
    const r = cellRect(c.col, c.row);
    roundRect(ctx, r.x + 2.5, r.y + 2.5, r.w - 5, r.h - 5, 3.5);
    ctx.stroke();
  }
}

function drawGhost() {
  const target = effectiveTarget();
  if (!target) return;
  const r = cellRect(target.col, target.row);
  ctx.save();
  ctx.globalAlpha = 0.30;
  drawBlock(ctx, r.x + 1, r.y + 1, r.w - 2, r.h - 2, selectedDesignID);
  ctx.restore();
  ctx.strokeStyle = css(APP_ACCENT);
  ctx.lineWidth = 1.5;
  ctx.setLineDash([4, 3]);
  roundRect(ctx, r.x + 1, r.y + 1, r.w - 2, r.h - 2, 3.5);
  ctx.stroke();
  ctx.setLineDash([]);
}

function drawSelection() {
  let cell, dashed;
  if (editMode.kind === 'selected') { cell = editMode.cell; dashed = false; }
  else if (editMode.kind === 'moving') { cell = editMode.cell; dashed = true; }
  else return;
  const r = cellRect(cell.col, cell.row);
  ctx.strokeStyle = css(APP_ACCENT);
  ctx.lineWidth = 2;
  ctx.setLineDash(dashed ? [4, 3] : []);
  roundRect(ctx, r.x + 1, r.y + 1, r.w - 2, r.h - 2, 3.5);
  ctx.stroke();
  ctx.setLineDash([]);
}

function drawMoveDestinations(cell) {
  ctx.strokeStyle = css(APP_ACCENT, 0.55);
  ctx.lineWidth = 1.2;
  for (const c of W.validMoveDestinations(world(), cell.col, cell.row)) {
    const r = cellRect(c.col, c.row);
    roundRect(ctx, r.x + 2.5, r.y + 2.5, r.w - 5, r.h - 5, 3.5);
    ctx.stroke();
  }
}

// Time-driven (deterministic) so motion stays smooth frame to frame.
const RICH_WATER = 5;        // run length that unlocks bubbles + loops
const LOOP_PERIOD = 10;      // s between the main fish's little loops
const LOOP_DURATION = 1.3;   // s the loop takes

// A fish patrols each run of >= 3 contiguous water blocks (gentle sine motion,
// slowing at each turn). Runs of >= 5 also get rising bubbles and occasional
// little loops.
function drawFish(tSeconds) {
  W.waterRuns(world()).forEach((run, i) => {
    const rowTop = (W.ROWS - 1 - run.row) * CELL_H;
    const cy = rowTop + CELL_H / 2;
    const margin = 7;
    const minX = run.startCol * CELL_W + margin;
    const maxX = (run.endCol + 1) * CELL_W - margin;
    const len = run.endCol - run.startCol + 1;
    const rich = len >= RICH_WATER;
    const seed = run.row * 0.7 + run.startCol * 0.5 + i; // desync runs

    if (rich) drawBubbles(tSeconds, run, rowTop, seed);

    const mid = (minX + maxX) / 2;
    const amp = (maxX - minX) / 2;
    const omega = (2 * Math.PI) / Math.max(3, len * 1.4);
    const angle = tSeconds * omega + seed;
    let fx = mid + amp * Math.sin(angle);
    let fy = cy;
    if (rich) {
      const loopT = (tSeconds + seed * 3) % LOOP_PERIOD;
      if (loopT < LOOP_DURATION) {
        const p = loopT / LOOP_DURATION;
        const r = Math.min(CELL_H * 0.55, 8);
        fx += r * Math.sin(2 * Math.PI * p);
        fy -= r * (1 - Math.cos(2 * Math.PI * p)); // up and over, back to start
      }
    }
    fishShape(fx, fy, Math.cos(angle) > 0);
  });
}

function drawBubbles(t, run, rowTop, seed) {
  const left = run.startCol * CELL_W;
  const width = (run.endCol + 1) * CELL_W - left;
  const count = Math.min(8, run.endCol - run.startCol + 1);
  ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
  for (let k = 0; k < count; k++) {
    const rise = (t * (0.32 + 0.05 * (k % 3)) + k * 0.37 + seed) % 1; // 0 bottom → 1 top
    const bx = left + ((k + 0.5) / count) * width + Math.sin(t * 1.3 + k) * 2;
    const by = rowTop + CELL_H - rise * CELL_H;
    ctx.globalAlpha = 0.55 * (1 - rise) + 0.1;
    ctx.beginPath();
    ctx.arc(bx, by, 0.9 + (1 - rise) * 1.0, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
}

function fishShape(x, y, facingRight, scale = 1, color = 'rgb(255, 138, 60)') {
  ctx.save();
  ctx.translate(x, y);
  if (!facingRight) ctx.scale(-1, 1);
  if (scale !== 1) ctx.scale(scale, scale);
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.ellipse(0, 0, 6, 3.6, 0, 0, Math.PI * 2); // body
  ctx.fill();
  ctx.beginPath();                                // tail
  ctx.moveTo(-5, 0);
  ctx.lineTo(-9.5, -3.4);
  ctx.lineTo(-9.5, 3.4);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = 'rgba(0,0,0,0.8)';              // eye
  ctx.beginPath();
  ctx.arc(2.6, -0.6, 0.85, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

// Flowers sprout on each run of >= 3 contiguous garden blocks: one per block,
// growing in over a couple of seconds (since the run was completed) and then
// swaying gently.
const FLOWER_COLORS = ['rgb(240,130,170)', 'rgb(245,210,90)', 'rgb(245,245,245)', 'rgb(235,110,110)'];

function drawFlowers(tSeconds) {
  W.gardenRuns(world()).forEach((run) => {
    const rowTop = (W.ROWS - 1 - run.row) * CELL_H;
    let newest = 0;
    for (const b of world().blocks) {
      if (b.row === run.row && b.designID === 'garden' && b.col >= run.startCol && b.col <= run.endCol) {
        newest = Math.max(newest, b.placedAt || 0);
      }
    }
    const ageSec = newest ? (Date.now() - newest) / 1000 : 99;
    for (let col = run.startCol; col <= run.endCol; col++) {
      flowerAt(col * CELL_W + CELL_W * 0.5, rowTop, col, tSeconds, ageSec);
    }
  });
}

function flowerAt(x, rowTop, col, t, ageSec) {
  const g = Math.max(0, Math.min(1, (ageSec - (col % 5) * 0.12) / 1.6)); // staggered grow-in
  if (g <= 0) return;
  const baseY = rowTop + 2;
  const height = CELL_H * 0.85 * g;
  const sway = Math.sin(t * 1.6 + col * 1.3) * 2 * g;
  const tipX = x + sway;
  const tipY = baseY - height;
  ctx.strokeStyle = 'rgb(70, 130, 60)';            // stem
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(x, baseY);
  ctx.quadraticCurveTo((x + tipX) / 2, baseY - height * 0.5, tipX, tipY);
  ctx.stroke();
  ctx.fillStyle = FLOWER_COLORS[col % FLOWER_COLORS.length]; // petals
  const petalR = 1.8 * g;
  const dist = 2.6 * g;
  for (let k = 0; k < 5; k++) {
    const a = (k / 5) * Math.PI * 2;
    ctx.beginPath();
    ctx.arc(tipX + Math.cos(a) * dist, tipY + Math.sin(a) * dist, petalR, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.fillStyle = 'rgb(250, 220, 90)';             // center
  ctx.beginPath();
  ctx.arc(tipX, tipY, 1.3 * g, 0, Math.PI * 2);
  ctx.fill();
}

// Continuous redraw loop, alive only while there's animated life (water or
// flowering garden) on the board.
function hasAmbientLife() {
  return W.waterRuns(world()).length > 0 || W.gardenRuns(world()).length > 0;
}
let ambientRAF = null;
function ambientLoop() {
  if (!hasAmbientLife()) { ambientRAF = null; return; }
  drawWorld();
  ambientRAF = requestAnimationFrame(ambientLoop);
}
function ensureAmbientLoop() {
  if (ambientRAF == null && hasAmbientLife()) {
    ambientRAF = requestAnimationFrame(ambientLoop);
  }
}

function drawInProgress() {
  if (!engine.isFocus()) return;
  const target = effectiveTarget();
  if (!target) return;
  const progress = engine.progress();
  if (progress <= 0) return;
  const r = cellRect(target.col, target.row);
  const fillHeight = r.h * progress;
  ctx.save();
  ctx.beginPath();
  ctx.rect(r.x, r.y + r.h - fillHeight, r.w, fillHeight);
  ctx.clip();
  drawBlock(ctx, r.x, r.y, r.w, r.h, selectedDesignID);
  ctx.restore();
}

// --- rendering: unlock banner --------------------------------------------

function renderUnlockBanner() {
  const banner = $('unlock-banner');
  if (!unlockAnnouncement) { banner.hidden = true; return; }
  banner.hidden = false;
  $('unlock-text').innerHTML = `New design unlocked: <strong>${unlockAnnouncement.name}</strong>`;
  drawSwatch($('unlock-swatch'), unlockAnnouncement);
}

function drawSwatch(canvasEl, design, isCracked = false) {
  const c = canvasEl.getContext('2d');
  const w = canvasEl.width, h = canvasEl.height;
  c.setTransform(1, 0, 0, 1, 0, 0);
  c.clearRect(0, 0, w, h);
  drawBlock(c, 1, 1, w - 2, h - 2, design.id, isCracked);
}

// --- rendering: phase controls -------------------------------------------

function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (k === 'class') node.className = v;
    else if (k === 'html') node.innerHTML = v;
    else if (k.startsWith('on')) node.addEventListener(k.slice(2), v);
    else node.setAttribute(k, v);
  }
  for (const child of children) {
    if (child == null) continue;
    node.append(child.nodeType ? child : document.createTextNode(child));
  }
  return node;
}

function renderControls() {
  controlsEl.innerHTML = '';
  const phase = engine.phase.kind;
  if (phase === 'idle') controlsEl.append(editMode.kind === 'none' ? idleControls() : editBar());
  else if (phase === 'focusRunning' || phase === 'focusPaused') controlsEl.append(focusControls());
  else if (phase === 'breakPrompt') controlsEl.append(breakPrompt());
  else controlsEl.append(breakControls());
}

function designPicker() {
  const picker = el('div', { class: 'design-picker' });
  const total = totalBlocksBuilt();
  for (const design of CATALOG) {
    const unlocked = design.unlockAt <= total;
    const selected = selectedDesignID === design.id;
    const swatchCanvas = el('canvas', { width: 36, height: 28 });
    const btn = el('button', {
      class: `swatch ${selected ? 'selected' : ''} ${unlocked ? '' : 'locked'}`,
      title: unlocked ? design.name : `Unlocks at ${design.unlockAt} blocks`,
      onclick: () => selectDesign(design),
    },
      swatchCanvas,
      el('span', { class: 'swatch-name' }, design.name),
      unlocked ? null : el('span', { class: 'swatch-lock' }, `🔒 at ${design.unlockAt}`),
    );
    picker.append(btn);
    drawSwatch(swatchCanvas, design);
  }
  return picker;
}

function idleControls() {
  const wrap = el('div', { class: 'controls' });
  wrap.append(designPicker());

  const durationRow = el('div', { class: 'duration-row' });
  for (const preset of [15, 25, 45, 60]) {
    durationRow.append(el('button', {
      class: `pill ${focusMinutes === preset ? 'selected' : ''}`,
      onclick: () => setFocusMinutes(preset),
    }, String(preset)));
  }
  const input = el('input', { class: 'duration-input', type: 'number', min: MIN_FOCUS_MINUTES, max: MAX_FOCUS_MINUTES, value: focusMinutes });
  input.addEventListener('change', () => setFocusMinutes(parseInt(input.value, 10) || focusMinutes));
  durationRow.append(input, el('span', { class: 'unit' }, 'min'));
  wrap.append(durationRow);

  wrap.append(el('p', { class: 'hint' },
    targetCell ? 'Building on the marked spot — click anywhere to move it, or a block to edit it'
               : 'Click anywhere on the grid to place your block, or a block to move or delete it'));

  wrap.append(el('button', {
    class: 'btn btn-primary btn-block',
    onclick: startFocus,
  }, `▶  Start ${focusMinutes}-minute focus`));
  return wrap;
}

function editBar() {
  const bar = el('div', { class: 'edit-bar' });
  if (editMode.kind === 'moving') {
    bar.append(
      el('span', { class: 'edit-label' }, 'Click a highlighted spot to move the block'),
      el('button', { class: 'btn', onclick: () => { editMode = { kind: 'none' }; render(); } }, 'Cancel'),
    );
    return bar;
  }
  const block = selectedBlock();
  if (!block) { editMode = { kind: 'none' }; return idleControls(); }
  const design = designForId(block.designID);
  const swatchCanvas = el('canvas', { width: 28, height: 22 });
  bar.append(
    swatchCanvas,
    el('span', { class: 'edit-label' }, block.isCracked ? 'Cracked block' : `${design.name} block`),
    el('button', { class: 'btn', onclick: () => { editMode = { kind: 'moving', cell: editMode.cell }; render(); } }, '↔ Move'),
    el('button', { class: 'btn btn-danger', onclick: deleteSelected }, '🗑 Delete'),
    el('button', { class: 'icon-btn', onclick: () => { editMode = { kind: 'none' }; render(); } }, '✕'),
  );
  drawSwatch(swatchCanvas, design, block.isCracked);
  return bar;
}

function deleteSelected() {
  if (editMode.kind !== 'selected') return;
  W.removeBlock(world(), editMode.cell.col, editMode.cell.row);
  Store.saveWorldFile(worldFile);
  editMode = { kind: 'none' };
  targetCell = null;
  render();
}

function timerHead(design, isBreak) {
  const head = el('div', { class: 'timer-head' });
  if (isBreak) {
    head.append(el('span', { html: '☕', style: 'font-size:28px' }));
  } else {
    const c = el('canvas', { width: 28, height: 22 });
    head.append(c);
    setTimeout(() => drawSwatch(c, design), 0);
  }
  head.append(el('span', { class: 'timer-time', id: 'live-countdown' }, countdownString(engine.remaining())));
  return head;
}

function focusControls() {
  const wrap = el('div', { class: 'controls' });
  const paused = engine.phase.kind === 'focusPaused';
  const grace = isInCancelGrace();
  const design = designForId(selectedDesignID);
  const subtitle = grace
    ? `Cancel within ${CANCEL_GRACE_MS / 1000}s — no broken block`
    : (paused ? `Paused — ${design.name} block in progress` : `Building a ${design.name} block`);
  wrap.append(el('div', { class: 'timer-display' },
    timerHead(design, false),
    el('div', { class: 'timer-sub' }, subtitle),
  ));
  const row = el('div', { class: 'btn-row' });
  row.append(
    paused
      ? el('button', { class: 'btn btn-primary', onclick: resume }, '▶ Resume')
      : el('button', { class: 'btn', onclick: pause }, '⏸ Pause'),
    grace
      ? el('button', { class: 'btn', onclick: cancelFocus }, '↩ Cancel')
      : el('button', { class: 'btn btn-danger', onclick: confirmAbandon }, '✕ Abandon'),
  );
  wrap.append(row);
  return wrap;
}

function confirmAbandon() {
  const msg = settings.crackedBlockOnAbandon
    ? 'Abandon this session? A cracked gray block will be placed where your block would have gone.'
    : 'Abandon this session? It will end without building a block.';
  if (confirm(msg)) abandonFocus();
}

function breakPrompt() {
  const wrap = el('div', { class: 'controls' });
  const kind = engine.phase.breakKind;
  const minutes = kind === 'long' ? settings.longBreakMinutes : settings.shortBreakMinutes;
  wrap.append(el('div', { class: 'timer-display' },
    el('div', { class: 'timer-time', style: 'font-size:24px' }, kind === 'long' ? 'Time for a long break' : 'Block built!'),
    el('div', { class: 'timer-sub' }, kind === 'long' ? `${minutes} minutes — you've earned it` : `Take a ${minutes}-minute break?`),
  ));
  const row = el('div', { class: 'btn-row' });
  row.append(
    el('button', { class: 'btn btn-primary', onclick: startBreak }, '☕ Start break'),
    el('button', { class: 'btn', onclick: skipBreak }, 'Skip'),
  );
  wrap.append(row);
  return wrap;
}

function breakControls() {
  const wrap = el('div', { class: 'controls' });
  const paused = engine.phase.kind === 'breakPaused';
  const kind = engine.phase.breakKind;
  wrap.append(el('div', { class: 'timer-display' },
    timerHead(null, true),
    el('div', { class: 'timer-sub' }, `${kind === 'long' ? 'Long break' : 'Short break'}${paused ? ' — paused' : ''}`),
  ));
  const row = el('div', { class: 'btn-row' });
  row.append(
    paused
      ? el('button', { class: 'btn btn-primary', onclick: resume }, '▶ Resume')
      : el('button', { class: 'btn', onclick: pause }, '⏸ Pause'),
    el('button', { class: 'btn', onclick: endBreakEarly }, 'End break'),
  );
  wrap.append(row);
  return wrap;
}

// --- timer chrome: live countdown, tab title, favicon --------------------

function updateTimerChrome() {
  const live = $('live-countdown');
  if (live) live.textContent = countdownString(engine.remaining());

  const phase = engine.phase.kind;
  let title = 'Pomolego';
  if (settings.showCountdownInTitle && (phase === 'focusRunning' || phase === 'focusPaused')) {
    title = `${countdownString(engine.remaining())} · Focus`;
  } else if (settings.showCountdownInTitle && (phase === 'breakRunning' || phase === 'breakPaused')) {
    title = `${countdownString(engine.remaining())} · Break`;
  }
  document.title = title;
  updateFavicon(phase);
}

let lastFaviconKey = '';
function updateFavicon(phase) {
  const focusing = phase === 'focusRunning' || phase === 'focusPaused';
  const key = focusing ? selectedDesignID : 'idle';
  if (key === lastFaviconKey) return;
  lastFaviconKey = key;
  const c = document.createElement('canvas');
  c.width = 32; c.height = 32;
  const fc = c.getContext('2d');
  if (focusing) {
    drawBlock(fc, 3, 6, 26, 20, selectedDesignID);
  } else {
    fc.fillStyle = css(APP_ACCENT);
    roundRect(fc, 4, 10, 24, 18, 4);
    fc.fill();
    fc.fillRect(9, 6, 5, 6);
    fc.fillRect(18, 6, 5, 6);
  }
  $('favicon').href = c.toDataURL('image/png');
}

// --- completion overlay (silent) -----------------------------------------

function showOverlay(event) {
  if (settings.animationPosition === 'off') return;
  const overlay = $('overlay');
  overlay.dataset.position = settings.animationPosition;
  overlay.hidden = false;
  overlay.classList.remove('hide');
  overlay.classList.add('show');

  const art = $('overlay-art');
  const text = $('overlay-text');
  art.innerHTML = '';

  if (event.type === 'blockBuilt') {
    const swatch = el('canvas', { width: 40, height: 30, class: 'drop-anim' });
    art.append(swatch);
    drawSwatch(swatch, event.design);
    spawnConfetti(art, event.design);
    text.textContent = `Block built — ${event.design.name}`;
  } else {
    art.append(el('span', { html: '☕', style: 'font-size:30px' }));
    text.textContent = "Break's over";
  }

  clearTimeout(overlayTimeout);
  overlayTimeout = setTimeout(() => {
    overlay.classList.remove('show');
    overlay.classList.add('hide');
    setTimeout(() => { overlay.hidden = true; }, 360);
  }, 1900);
}

function spawnConfetti(art, design) {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  for (let i = 0; i < 8; i++) {
    const angle = (i / 8) * Math.PI * 2;
    const distance = 26 + (i % 3) * 8;
    const dot = el('span', { class: 'confetti' });
    dot.style.background = i % 2 === 0 ? css(design.base) : css(design.accent);
    art.append(dot);
    // Force a frame so the transition runs.
    requestAnimationFrame(() => {
      dot.style.transition = 'transform 0.7s ease-out, opacity 0.7s ease-out';
      dot.style.transform = `translate(${Math.cos(angle) * distance}px, ${Math.sin(angle) * distance}px)`;
      dot.classList.add('burst');
    });
  }
}

// --- settings modal ------------------------------------------------------

function openSettings() {
  const body = $('settings-body');
  body.innerHTML = '';

  body.append(settingGroup('Durations', [
    numberRow('Focus', 'focusMinutes', MIN_FOCUS_MINUTES, MAX_FOCUS_MINUTES),
    numberRow('Short break', 'shortBreakMinutes', 1, 60),
    numberRow('Long break', 'longBreakMinutes', 1, 120),
    numberRow('Sessions before long break', 'sessionsBeforeLongBreak', 2, 12),
  ]));

  body.append(settingGroup('Flow', [
    toggleRow('Auto-start breaks', 'autoStartBreaks'),
    toggleRow('Auto-start next focus after a break', 'autoStartNextFocus'),
    numberRow('Reset cycle after idle (minutes)', 'idleResetMinutes', 15, 480),
  ]));

  body.append(settingGroup('Appearance', [
    selectRow('Completion animation', 'animationPosition', [
      ['corner', 'Top corner'], ['center', 'Center of screen'], ['off', 'Off'],
    ]),
    toggleRow('Show countdown in browser tab', 'showCountdownInTitle'),
    toggleRow('Cracked block when a session is abandoned', 'crackedBlockOnAbandon'),
  ]));

  const danger = settingGroup('Danger zone', []);
  danger.append(el('p', { class: 'setting-note' }, 'Archives the current world and starts an empty one. Statistics keep the full history.'));
  danger.append(el('button', {
    class: 'btn btn-danger', onclick: () => {
      if (world().blocks.length && confirm(`Archive your world (${world().blocks.length} blocks) and start fresh? This cannot be undone.`)) {
        startFreshCanvas();
        $('settings-modal').hidden = true;
      }
    },
  }, 'Start a fresh canvas…'));
  body.append(danger);

  $('settings-modal').hidden = false;
}

function settingGroup(title, rows) {
  const group = el('div', { class: 'setting-group' }, el('h3', {}, title));
  rows.forEach((r) => group.append(r));
  return group;
}

function commitSetting(key, value) {
  settings[key] = value;
  Store.saveSettings(settings);
  if (key === 'focusMinutes') { focusMinutes = value; }
  if (key === 'sessionsBeforeLongBreak' || key === 'idleResetMinutes') {
    engine.config = {
      sessionsBeforeLongBreak: settings.sessionsBeforeLongBreak,
      idleResetGap: settings.idleResetMinutes * 60000,
    };
  }
  render();
}

function numberRow(label, key, min, max) {
  const input = el('input', { type: 'number', min, max, value: settings[key] });
  input.addEventListener('change', () => {
    const v = Math.min(max, Math.max(min, parseInt(input.value, 10) || min));
    input.value = v;
    commitSetting(key, v);
  });
  return el('div', { class: 'setting-row' }, el('label', {}, label), input);
}

function toggleRow(label, key) {
  const input = el('input', { type: 'checkbox' });
  input.checked = !!settings[key];
  input.addEventListener('change', () => commitSetting(key, input.checked));
  const toggle = el('label', { class: 'toggle' }, input, el('span', { class: 'track' }));
  return el('div', { class: 'setting-row' }, el('label', {}, label), toggle);
}

function selectRow(label, key, options) {
  const select = el('select', {});
  for (const [value, text] of options) {
    const opt = el('option', { value }, text);
    if (settings[key] === value) opt.selected = true;
    select.append(opt);
  }
  select.addEventListener('change', () => commitSetting(key, select.value));
  return el('div', { class: 'setting-row' }, el('label', {}, label), select);
}

// --- statistics modal ----------------------------------------------------

function openStats() {
  const s = computeStats(sessions);
  const body = $('stats-body');
  body.innerHTML = '';

  body.append(el('div', { class: 'stats-section' },
    el('h3', {}, 'Today'),
    statCards([
      ['Blocks built', s.blocksToday],
      ['Focus minutes', s.focusMinutesToday],
      ['Abandoned', s.abandonedToday],
      ['Breaks taken', s.breaksToday],
    ]),
  ));

  body.append(chartSection('Focus minutes — last 14 days', (c) => barChart(c, s.last14Days.map((d) => d.focusMinutes), css(APP_ACCENT))));
  body.append(chartSection('Blocks by design', (c) => designChart(c, s.designCounts)));
  body.append(chartSection('Completed vs abandoned — last 14 days', (c) => outcomeChart(c, s.outcomesByDay)));
  body.querySelector('.stats-section:last-child').append(legend());

  body.append(el('div', { class: 'stats-section' },
    el('h3', {}, 'Streaks'),
    statCards([
      ['Current streak', `${s.currentStreak} day${s.currentStreak === 1 ? '' : 's'}`],
      ['Best streak', `${s.bestStreak} day${s.bestStreak === 1 ? '' : 's'}`],
    ], 2),
  ));

  body.append(el('div', { class: 'stats-section' },
    el('h3', {}, 'All time'),
    statCards([
      ['Blocks', s.totalBlocks],
      ['Focus hours', s.totalFocusHours.toFixed(1)],
      ['Completion rate', s.completionRateText],
    ], 3),
  ));

  const collection = el('div', { class: 'stats-section' },
    el('h3', {}, 'Collection'),
    el('p', { class: 'setting-note' }, `${s.unlockedCount} of ${s.totalDesigns} designs unlocked`),
  );
  if (s.collectionProgress) {
    const p = s.collectionProgress;
    collection.append(
      el('p', { class: 'setting-note' }, `Next: ${p.next.name} at ${p.next.unlockAt} blocks (${p.toGo} to go)`),
      el('div', { class: 'progress-track' }, el('div', { class: 'progress-fill', style: `width:${Math.round((p.into / p.span) * 100)}%` })),
    );
  } else {
    collection.append(el('p', { class: 'setting-note' }, 'Everything unlocked — the moon is yours. 🌙'));
  }
  body.append(collection);

  $('stats-modal').hidden = false;
}

function statCards(items, cols = 4) {
  const grid = el('div', { class: `stat-cards cards-${cols}` });
  for (const [label, value] of items) {
    grid.append(el('div', { class: 'stat-card' },
      el('div', { class: 'stat-value' }, String(value)),
      el('div', { class: 'stat-label' }, label),
    ));
  }
  return grid;
}

function chartSection(title, drawFn) {
  const c = el('canvas', { width: 560, height: 150 });
  const section = el('div', { class: 'stats-section' }, el('h3', {}, title), c);
  setTimeout(() => drawFn(c), 0);
  return section;
}

function legend() {
  return el('div', { class: 'legend' },
    el('span', {}, el('i', { style: 'background: rgb(76,175,80)' }), 'Completed'),
    el('span', {}, el('i', { style: 'background: rgba(199,70,60,0.75)' }), 'Abandoned'),
  );
}

function barChart(canvasEl, values, color) {
  const c = canvasEl.getContext('2d');
  const w = canvasEl.width, h = canvasEl.height;
  c.clearRect(0, 0, w, h);
  const max = Math.max(1, ...values);
  const n = values.length;
  const gap = 4;
  const barW = (w - gap * (n + 1)) / n;
  c.fillStyle = color;
  values.forEach((v, i) => {
    const barH = (v / max) * (h - 20);
    c.fillRect(gap + i * (barW + gap), h - barH - 4, barW, barH);
  });
}

function designChart(canvasEl, counts) {
  const c = canvasEl.getContext('2d');
  const w = canvasEl.width, h = canvasEl.height;
  c.clearRect(0, 0, w, h);
  if (counts.length === 0) { emptyLabel(c, w, h); return; }
  const max = Math.max(1, ...counts.map((d) => d.count));
  const rowH = Math.min(20, (h - 8) / counts.length);
  c.font = '11px -apple-system, system-ui, sans-serif';
  c.textBaseline = 'middle';
  counts.slice(0, Math.floor((h - 8) / rowH)).forEach((d, i) => {
    const y = 4 + i * rowH;
    const labelW = 76;
    c.fillStyle = getComputedStyle(document.body).getPropertyValue('--text-secondary');
    c.textAlign = 'right';
    c.fillText(d.design.name, labelW - 6, y + rowH / 2);
    const barW = ((w - labelW - 30) * d.count) / max;
    c.fillStyle = css(d.design.base);
    c.fillRect(labelW, y + 2, barW, rowH - 5);
    c.fillStyle = getComputedStyle(document.body).getPropertyValue('--text');
    c.textAlign = 'left';
    c.fillText(String(d.count), labelW + barW + 5, y + rowH / 2);
  });
}

function outcomeChart(canvasEl, days) {
  const c = canvasEl.getContext('2d');
  const w = canvasEl.width, h = canvasEl.height;
  c.clearRect(0, 0, w, h);
  const max = Math.max(1, ...days.map((d) => d.completed + d.abandoned));
  const n = days.length;
  const gap = 4;
  const barW = (w - gap * (n + 1)) / n;
  days.forEach((d, i) => {
    const x = gap + i * (barW + gap);
    const total = d.completed + d.abandoned;
    if (total === 0) return;
    const fullH = (total / max) * (h - 20);
    const compH = (d.completed / total) * fullH;
    c.fillStyle = 'rgba(199,70,60,0.75)';
    c.fillRect(x, h - fullH - 4, barW, fullH);
    c.fillStyle = 'rgb(76,175,80)';
    c.fillRect(x, h - compH - 4, barW, compH);
  });
}

function emptyLabel(c, w, h) {
  c.fillStyle = 'rgba(127,127,127,0.6)';
  c.font = '13px -apple-system, system-ui, sans-serif';
  c.textAlign = 'center';
  c.textBaseline = 'middle';
  c.fillText('No blocks yet — complete a session!', w / 2, h / 2);
}

init();
