import Foundation

enum BreakKind: String, Codable, Equatable {
    case short
    case long
}

enum TimerPhase: Equatable {
    case idle
    case focusRunning(endDate: Date)
    case focusPaused(remaining: TimeInterval)
    case breakPrompt(BreakKind)
    case breakRunning(kind: BreakKind, endDate: Date)
    case breakPaused(kind: BreakKind, remaining: TimeInterval)

    var isFocus: Bool {
        switch self {
        case .focusRunning, .focusPaused: return true
        default: return false
        }
    }

    var isBreak: Bool {
        switch self {
        case .breakRunning, .breakPaused: return true
        default: return false
        }
    }

    var isRunning: Bool {
        switch self {
        case .focusRunning, .breakRunning: return true
        default: return false
        }
    }
}

/// Wall-clock based Pomodoro state machine. Remaining time is always derived
/// from a stored `endDate`, never from accumulated ticks, so it survives
/// sleep, lag, and app restarts. `now` is injectable for tests.
final class TimerEngine {
    enum Event: Equatable {
        case focusCompleted(proposedBreak: BreakKind)
        case breakEnded(BreakKind)
    }

    struct Config {
        var sessionsBeforeLongBreak: Int = 4
        var idleResetGap: TimeInterval = 2 * 3600
    }

    var now: () -> Date
    var config: Config

    private(set) var phase: TimerPhase = .idle
    private(set) var plannedDuration: TimeInterval = 0
    private(set) var completedSinceLongBreak: Int = 0
    private(set) var lastFocusEndedAt: Date?

    init(now: @escaping () -> Date = { Date() }, config: Config = Config()) {
        self.now = now
        self.config = config
    }

    // MARK: - Derived

    /// Clamped to 0...plannedDuration so a system clock change can never
    /// produce a negative or absurdly large countdown.
    func remaining() -> TimeInterval {
        switch phase {
        case .idle, .breakPrompt:
            return 0
        case .focusRunning(let end), .breakRunning(_, let end):
            return max(0, min(plannedDuration, end.timeIntervalSince(now())))
        case .focusPaused(let remaining), .breakPaused(_, let remaining):
            return max(0, min(plannedDuration, remaining))
        }
    }

    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        switch phase {
        case .focusRunning, .focusPaused, .breakRunning, .breakPaused:
            return 1 - remaining() / plannedDuration
        case .idle, .breakPrompt:
            return 0
        }
    }

    // MARK: - Transitions

    func startFocus(duration: TimeInterval) {
        guard case .idle = phase else { return }
        let n = now()
        if let last = lastFocusEndedAt, n.timeIntervalSince(last) > config.idleResetGap {
            completedSinceLongBreak = 0
        }
        plannedDuration = duration
        phase = .focusRunning(endDate: n.addingTimeInterval(duration))
    }

    func pause() {
        switch phase {
        case .focusRunning:
            phase = .focusPaused(remaining: remaining())
        case .breakRunning(let kind, _):
            phase = .breakPaused(kind: kind, remaining: remaining())
        default:
            break
        }
    }

    func resume() {
        switch phase {
        case .focusPaused(let remaining):
            phase = .focusRunning(endDate: now().addingTimeInterval(remaining))
        case .breakPaused(let kind, let remaining):
            phase = .breakRunning(kind: kind, endDate: now().addingTimeInterval(remaining))
        default:
            break
        }
    }

    /// Give up the running focus session. The caller is responsible for the
    /// cracked-block consequence and logging.
    func abandonFocus() {
        guard phase.isFocus else { return }
        lastFocusEndedAt = now()
        phase = .idle
    }

    func startBreak(duration: TimeInterval) {
        guard case .breakPrompt(let kind) = phase else { return }
        plannedDuration = duration
        phase = .breakRunning(kind: kind, endDate: now().addingTimeInterval(duration))
    }

    func skipBreak() {
        guard case .breakPrompt(let kind) = phase else { return }
        // Skipping a long break still resets the cycle; otherwise the very
        // next session would immediately propose another long break.
        if kind == .long { completedSinceLongBreak = 0 }
        phase = .idle
    }

    /// Ends a running break early (counts as taken).
    func endBreakEarly() {
        guard case .breakRunning(let kind, _) = phase else {
            if case .breakPaused(let kind, _) = phase {
                if kind == .long { completedSinceLongBreak = 0 }
                phase = .idle
            }
            return
        }
        if kind == .long { completedSinceLongBreak = 0 }
        phase = .idle
    }

    /// Advance the machine against the wall clock. Call on every UI tick and
    /// on wake-from-sleep. Returns an event when a deadline passed.
    @discardableResult
    func tick() -> Event? {
        switch phase {
        case .focusRunning(let end) where now() >= end:
            completedSinceLongBreak += 1
            lastFocusEndedAt = end
            let kind: BreakKind = completedSinceLongBreak >= config.sessionsBeforeLongBreak ? .long : .short
            phase = .breakPrompt(kind)
            return .focusCompleted(proposedBreak: kind)
        case .breakRunning(let kind, let end) where now() >= end:
            if kind == .long { completedSinceLongBreak = 0 }
            phase = .idle
            return .breakEnded(kind)
        default:
            return nil
        }
    }

    // MARK: - Restore (crash / relaunch recovery)

    func restore(phase: TimerPhase, plannedDuration: TimeInterval,
                 completedSinceLongBreak: Int, lastFocusEndedAt: Date?) {
        self.phase = phase
        self.plannedDuration = plannedDuration
        self.completedSinceLongBreak = completedSinceLongBreak
        self.lastFocusEndedAt = lastFocusEndedAt
    }
}
