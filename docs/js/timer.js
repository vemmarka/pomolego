// Wall-clock Pomodoro state machine — mirrors Core/TimerEngine.swift.
// Remaining time is always derived from a stored endDate (epoch ms), never
// from accumulated ticks, so it survives sleep, lag, and tab backgrounding.

// Phase shapes:
//   { kind: 'idle' }
//   { kind: 'focusRunning', endDate }
//   { kind: 'focusPaused', remaining }            // remaining in ms
//   { kind: 'breakPrompt', breakKind }            // 'short' | 'long'
//   { kind: 'breakRunning', breakKind, endDate }
//   { kind: 'breakPaused', breakKind, remaining }

export class TimerEngine {
  constructor(now = () => Date.now()) {
    this.now = now;
    this.config = { sessionsBeforeLongBreak: 4, idleResetGap: 2 * 3600 * 1000 };
    this.phase = { kind: 'idle' };
    this.plannedDuration = 0; // ms
    this.completedSinceLongBreak = 0;
    this.lastFocusEndedAt = null; // epoch ms
  }

  isFocus() { return this.phase.kind === 'focusRunning' || this.phase.kind === 'focusPaused'; }
  isBreak() { return this.phase.kind === 'breakRunning' || this.phase.kind === 'breakPaused'; }
  isRunning() { return this.phase.kind === 'focusRunning' || this.phase.kind === 'breakRunning'; }

  // Clamped to 0..plannedDuration so a clock change can't produce a negative
  // or absurd countdown. Returns ms.
  remaining() {
    const p = this.phase;
    switch (p.kind) {
      case 'focusRunning':
      case 'breakRunning':
        return Math.max(0, Math.min(this.plannedDuration, p.endDate - this.now()));
      case 'focusPaused':
      case 'breakPaused':
        return Math.max(0, Math.min(this.plannedDuration, p.remaining));
      default:
        return 0;
    }
  }

  progress() {
    if (this.plannedDuration <= 0) return 0;
    if (this.phase.kind === 'idle' || this.phase.kind === 'breakPrompt') return 0;
    return 1 - this.remaining() / this.plannedDuration;
  }

  startFocus(durationMs) {
    if (this.phase.kind !== 'idle') return;
    const n = this.now();
    if (this.lastFocusEndedAt != null && n - this.lastFocusEndedAt > this.config.idleResetGap) {
      this.completedSinceLongBreak = 0;
    }
    this.plannedDuration = durationMs;
    this.phase = { kind: 'focusRunning', endDate: n + durationMs };
  }

  pause() {
    if (this.phase.kind === 'focusRunning') {
      this.phase = { kind: 'focusPaused', remaining: this.remaining() };
    } else if (this.phase.kind === 'breakRunning') {
      this.phase = { kind: 'breakPaused', breakKind: this.phase.breakKind, remaining: this.remaining() };
    }
  }

  resume() {
    if (this.phase.kind === 'focusPaused') {
      this.phase = { kind: 'focusRunning', endDate: this.now() + this.phase.remaining };
    } else if (this.phase.kind === 'breakPaused') {
      this.phase = { kind: 'breakRunning', breakKind: this.phase.breakKind, endDate: this.now() + this.phase.remaining };
    }
  }

  abandonFocus() {
    if (!this.isFocus()) return;
    this.lastFocusEndedAt = this.now();
    this.phase = { kind: 'idle' };
  }

  startBreak(durationMs) {
    if (this.phase.kind !== 'breakPrompt') return;
    this.plannedDuration = durationMs;
    this.phase = { kind: 'breakRunning', breakKind: this.phase.breakKind, endDate: this.now() + durationMs };
  }

  skipBreak() {
    if (this.phase.kind !== 'breakPrompt') return;
    if (this.phase.breakKind === 'long') this.completedSinceLongBreak = 0;
    this.phase = { kind: 'idle' };
  }

  endBreakEarly() {
    if (this.phase.kind === 'breakRunning' || this.phase.kind === 'breakPaused') {
      if (this.phase.breakKind === 'long') this.completedSinceLongBreak = 0;
      this.phase = { kind: 'idle' };
    }
  }

  // Advance against the wall clock. Returns an event when a deadline passed:
  //   { type: 'focusCompleted', proposedBreak } or { type: 'breakEnded', breakKind }
  tick() {
    const p = this.phase;
    if (p.kind === 'focusRunning' && this.now() >= p.endDate) {
      this.completedSinceLongBreak += 1;
      this.lastFocusEndedAt = p.endDate;
      const breakKind = this.completedSinceLongBreak >= this.config.sessionsBeforeLongBreak ? 'long' : 'short';
      this.phase = { kind: 'breakPrompt', breakKind };
      return { type: 'focusCompleted', proposedBreak: breakKind };
    }
    if (p.kind === 'breakRunning' && this.now() >= p.endDate) {
      const breakKind = p.breakKind;
      if (breakKind === 'long') this.completedSinceLongBreak = 0;
      this.phase = { kind: 'idle' };
      return { type: 'breakEnded', breakKind };
    }
    return null;
  }

  restore(snapshot) {
    this.phase = snapshot.phase;
    this.plannedDuration = snapshot.plannedDuration;
    this.completedSinceLongBreak = snapshot.completedSinceLongBreak;
    this.lastFocusEndedAt = snapshot.lastFocusEndedAt;
  }
}

export function countdownString(ms) {
  const total = Math.round(ms / 1000);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  const pad = (n) => String(n).padStart(2, '0');
  if (hours > 0) return `${hours}:${pad(minutes)}:${pad(seconds)}`;
  return `${pad(minutes)}:${pad(seconds)}`;
}
