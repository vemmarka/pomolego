// Persistence via localStorage — the web equivalent of the native app's
// JSON files in Application Support. Settings, world, session log, and
// running-timer state for seamless resume after a refresh or tab close.

const KEYS = {
  world: 'pomolego.world',
  sessions: 'pomolego.sessions',
  running: 'pomolego.running',
  settings: 'pomolego.settings',
};

export const DEFAULT_SETTINGS = {
  focusMinutes: 25,
  shortBreakMinutes: 5,
  longBreakMinutes: 20,
  sessionsBeforeLongBreak: 4,
  idleResetMinutes: 120,
  autoStartBreaks: false,
  autoStartNextFocus: false,
  animationPosition: 'corner', // 'corner' | 'center' | 'off'
  showCountdownInTitle: true,
  crackedBlockOnAbandon: true,
  selectedDesignID: 'brick',
  customDurations: [], // extra focus presets the user has typed in
};

function load(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw == null ? fallback : JSON.parse(raw);
  } catch {
    return fallback;
  }
}

function save(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* storage full or unavailable — non-fatal */
  }
}

export const Store = {
  // world.json equivalent: { current: World, archived: [{ archivedAt, blocks }] }
  loadWorldFile() {
    return load(KEYS.world, { current: { blocks: [] }, archived: [] });
  },
  saveWorldFile(worldFile) { save(KEYS.world, worldFile); },

  loadSessions() { return load(KEYS.sessions, []); },
  saveSessions(sessions) { save(KEYS.sessions, sessions); },

  loadRunning() { return load(KEYS.running, null); },
  saveRunning(state) {
    if (state) save(KEYS.running, state);
    else localStorage.removeItem(KEYS.running);
  },

  loadSettings() {
    return { ...DEFAULT_SETTINGS, ...load(KEYS.settings, {}) };
  },
  saveSettings(settings) { save(KEYS.settings, settings); },

  // A full backup snapshot for export/import (everything except the
  // transient running-timer state).
  exportData() {
    return {
      app: 'pomolego',
      version: 1,
      exportedAt: new Date().toISOString(),
      world: this.loadWorldFile(),
      sessions: this.loadSessions(),
      settings: load(KEYS.settings, {}),
    };
  },

  // Restore a backup. Returns true on success. Validates shape loosely so a
  // stray file can't corrupt storage.
  importData(data) {
    if (!data || data.app !== 'pomolego' || typeof data !== 'object') return false;
    if (data.world && data.world.current && Array.isArray(data.world.current.blocks)) {
      save(KEYS.world, data.world);
    }
    if (Array.isArray(data.sessions)) save(KEYS.sessions, data.sessions);
    if (data.settings && typeof data.settings === 'object') save(KEYS.settings, data.settings);
    localStorage.removeItem(KEYS.running); // a restored snapshot has no live timer
    return true;
  },
};
