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
};
