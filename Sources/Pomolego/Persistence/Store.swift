import Foundation

/// Snapshot of an in-flight timer so a quit or crash mid-session resumes
/// seamlessly on relaunch. If `endDate` already passed while the app was
/// closed, AppState completes the session on launch.
struct RunningState: Codable {
    enum PhaseKind: String, Codable {
        case focusRunning, focusPaused, breakPrompt, breakRunning, breakPaused
    }

    var phaseKind: PhaseKind
    var breakKind: BreakKind?
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    var plannedDuration: TimeInterval
    var startedAt: Date
    var designID: String?
    var targetCell: GridCell?
    var completedSinceLongBreak: Int
    var lastFocusEndedAt: Date?
}

/// JSON persistence in ~/Library/Application Support/Pomolego/.
/// All writes are atomic; all loads tolerate missing files.
final class Store {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var worldURL: URL { directory.appendingPathComponent("world.json") }
    private var sessionsURL: URL { directory.appendingPathComponent("sessions.json") }
    private var runningURL: URL { directory.appendingPathComponent("running.json") }

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                      in: .userDomainMask).first!
            self.directory = appSupport.appendingPathComponent("Pomolego", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory,
                                                 withIntermediateDirectories: true)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Generic helpers

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - World

    func loadWorld() -> WorldFile {
        load(WorldFile.self, from: worldURL) ?? WorldFile()
    }

    func saveWorld(_ world: WorldFile) {
        save(world, to: worldURL)
    }

    // MARK: - Sessions

    func loadSessions() -> [SessionRecord] {
        load([SessionRecord].self, from: sessionsURL) ?? []
    }

    func saveSessions(_ sessions: [SessionRecord]) {
        save(sessions, to: sessionsURL)
    }

    // MARK: - Running timer state

    func loadRunningState() -> RunningState? {
        load(RunningState.self, from: runningURL)
    }

    func saveRunningState(_ state: RunningState?) {
        if let state {
            save(state, to: runningURL)
        } else {
            try? FileManager.default.removeItem(at: runningURL)
        }
    }

    // MARK: - Backup (export / import)

    /// Settings keys safe to round-trip in a backup. Shared with the web
    /// version so a backup made there applies the matching keys here.
    private static let backupSettingsKeys = [
        AppSettings.focusMinutesKey, AppSettings.shortBreakMinutesKey,
        AppSettings.longBreakMinutesKey, AppSettings.sessionsBeforeLongBreakKey,
        AppSettings.idleResetMinutesKey, AppSettings.autoStartBreaksKey,
        AppSettings.autoStartNextFocusKey, AppSettings.animationPositionKey,
        AppSettings.menuBarShowsCountdownKey, AppSettings.crackedBlockOnAbandonKey,
        AppSettings.selectedDesignIDKey, AppSettings.customDurationsKey,
    ]

    /// A full backup as pretty-printed JSON, matching the web envelope:
    /// { app, version, exportedAt, world, sessions, settings }.
    func exportData() -> Data? {
        func jsonObject<T: Encodable>(_ value: T) -> Any? {
            guard let data = try? encoder.encode(value) else { return nil }
            return try? JSONSerialization.jsonObject(with: data)
        }
        var settings: [String: Any] = [:]
        for key in Self.backupSettingsKeys {
            if let v = UserDefaults.standard.object(forKey: key) { settings[key] = v }
        }
        let payload: [String: Any] = [
            "app": "pomolego",
            "version": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "world": jsonObject(loadWorld()) ?? [:],
            "sessions": jsonObject(loadSessions()) ?? [],
            "settings": settings,
        ]
        return try? JSONSerialization.data(withJSONObject: payload,
                                           options: [.prettyPrinted, .sortedKeys])
    }

    /// Restore a backup. Returns true on success. World and sessions are
    /// always restored when valid; known settings keys apply best-effort.
    @discardableResult
    func importData(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["app"] as? String == "pomolego" else { return false }

        if let worldObj = root["world"],
           let worldData = try? JSONSerialization.data(withJSONObject: worldObj),
           let world = try? decoder.decode(WorldFile.self, from: worldData) {
            saveWorld(world)
        }
        if let sessionsObj = root["sessions"],
           let sessionsData = try? JSONSerialization.data(withJSONObject: sessionsObj),
           let sessions = try? decoder.decode([SessionRecord].self, from: sessionsData) {
            saveSessions(sessions)
        }
        if let settings = root["settings"] as? [String: Any] {
            for key in Self.backupSettingsKeys where settings[key] != nil {
                UserDefaults.standard.set(settings[key], forKey: key)
            }
        }
        saveRunningState(nil) // a restored snapshot has no live timer
        return true
    }
}
