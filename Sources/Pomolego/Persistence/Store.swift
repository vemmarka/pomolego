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
}
