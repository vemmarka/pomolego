// Statistics derived entirely from the append-only session log — mirrors
// the Statistics struct in Views/StatisticsView.swift.

import { CATALOG, designForId, unlockedDesigns, nextUnlock } from './designs.js';

function startOfDay(ms) {
  const d = new Date(ms);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function sameDay(a, b) {
  return startOfDay(a) === startOfDay(b);
}

function dayKey(ms) {
  return startOfDay(ms);
}

export function computeStats(sessions, now = Date.now()) {
  const completed = sessions.filter((s) => s.kind === 'focus' && s.outcome === 'completed');
  const abandoned = sessions.filter((s) => s.kind === 'focus' && s.outcome === 'abandoned');

  const blocksToday = completed.filter((s) => sameDay(s.endedAt, now)).length;
  const focusMinutesToday = Math.floor(
    completed.filter((s) => sameDay(s.endedAt, now)).reduce((sum, s) => sum + s.plannedDuration, 0) / 60000
  );
  const abandonedToday = abandoned.filter((s) => sameDay(s.endedAt, now)).length;
  const breaksToday = sessions.filter((s) =>
    (s.kind === 'shortBreak' || s.kind === 'longBreak') && s.outcome === 'completed' && sameDay(s.endedAt, now)
  ).length;

  // 14 days, oldest first.
  const days = [];
  for (let i = 13; i >= 0; i--) {
    days.push(startOfDay(now) - i * 86400000);
  }

  const last14Days = days.map((day) => ({
    day,
    focusMinutes: Math.floor(
      completed.filter((s) => sameDay(s.endedAt, day)).reduce((sum, s) => sum + s.plannedDuration, 0) / 60000
    ),
  }));

  // Blocks by design.
  const byDesign = new Map();
  for (const s of completed) {
    const id = s.designID || 'brick';
    byDesign.set(id, (byDesign.get(id) || 0) + 1);
  }
  const designCounts = [...byDesign.entries()]
    .map(([id, count]) => ({ design: designForId(id), count }))
    .sort((a, b) => b.count - a.count);

  const outcomesByDay = days.map((day) => ({
    day,
    completed: completed.filter((s) => sameDay(s.endedAt, day)).length,
    abandoned: abandoned.filter((s) => sameDay(s.endedAt, day)).length,
  }));

  // Streaks: consecutive days with at least one completed block.
  const daysWithBlocks = new Set(completed.map((s) => dayKey(s.endedAt)));
  let currentStreak = 0;
  let probe = startOfDay(now);
  if (!daysWithBlocks.has(probe)) probe -= 86400000;
  while (daysWithBlocks.has(probe)) {
    currentStreak += 1;
    probe -= 86400000;
  }

  let bestStreak = 0;
  for (const day of daysWithBlocks) {
    if (daysWithBlocks.has(day - 86400000)) continue; // not a run start
    let length = 0;
    let cursor = day;
    while (daysWithBlocks.has(cursor)) {
      length += 1;
      cursor += 86400000;
    }
    bestStreak = Math.max(bestStreak, length);
  }
  bestStreak = Math.max(bestStreak, currentStreak);

  const totalBlocks = completed.length;
  const totalFocusHours = completed.reduce((sum, s) => sum + s.plannedDuration, 0) / 3600000;
  const attempts = completed.length + abandoned.length;
  const completionRateText = attempts === 0
    ? '—'
    : `${Math.round((completed.length / attempts) * 100)}%`;

  const unlockedCount = unlockedDesigns(totalBlocks).length;
  const next = nextUnlock(totalBlocks);
  let collectionProgress = null;
  if (next) {
    const previous = Math.max(0, ...CATALOG.filter((d) => d.unlockAt <= totalBlocks).map((d) => d.unlockAt));
    const span = Math.max(1, next.unlockAt - previous);
    collectionProgress = {
      next,
      into: totalBlocks - previous,
      span,
      toGo: next.unlockAt - totalBlocks,
    };
  }

  return {
    blocksToday, focusMinutesToday, abandonedToday, breaksToday,
    last14Days, designCounts, outcomesByDay,
    currentStreak, bestStreak,
    totalBlocks, totalFocusHours, completionRateText,
    unlockedCount, totalDesigns: CATALOG.length, collectionProgress,
  };
}
