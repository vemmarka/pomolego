import AppKit
import Combine
import SwiftUI

enum OverlayEvent {
    case blockBuilt(BlockDesign)
    case breakOver
}

/// World editing (delete / move existing blocks) is available while idle.
enum WorldEditMode: Equatable {
    case none
    case selected(GridCell)
    case moving(GridCell)
}

/// Central orchestrator: owns the timer engine, world, and session log;
/// publishes UI state; persists every transition.
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var phase: TimerPhase = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var worldFile: WorldFile
    @Published private(set) var sessions: [SessionRecord]
    @Published var selectedDesignID: String
    @Published var targetCell: GridCell?
    @Published var unlockAnnouncement: BlockDesign?
    @Published private(set) var editMode: WorldEditMode = .none
    @Published var focusMinutes: Int {
        didSet { AppSettings.focusMinutes = focusMinutes }
    }

    /// Set by the AppKit layer to receive status item refreshes and
    /// overlay requests.
    var onStatusUpdate: (() -> Void)?
    var onOverlay: ((OverlayEvent) -> Void)?

    private let engine: TimerEngine
    private let store: Store
    private var ticker: Timer?
    private var currentSessionStart: Date?

    var world: World { worldFile.current }
    var totalBlocksBuilt: Int { sessions.totalBlocksBuilt }
    var unlockedDesigns: [BlockDesign] { BlockDesign.unlocked(totalBlocksBuilt: totalBlocksBuilt) }

    func isUnlocked(_ design: BlockDesign) -> Bool {
        design.unlockAt <= totalBlocksBuilt
    }

    var currentDesign: BlockDesign { BlockDesign.design(for: selectedDesignID) }

    /// 0...1 fraction of the running session, drives the in-progress fill.
    var sessionProgress: Double { engine.progress }

    var proposedBreakKind: BreakKind? {
        if case .breakPrompt(let kind) = phase { return kind }
        return nil
    }

    /// The cell the in-progress block will land on (explicit pick or default).
    var effectiveTarget: GridCell? {
        if let cell = targetCell, world.isValidPlacement(cell) { return cell }
        return world.defaultTarget()
    }

    init(store: Store = Store()) {
        AppSettings.registerDefaults()
        self.store = store
        self.worldFile = store.loadWorld()
        self.sessions = store.loadSessions()
        self.selectedDesignID = AppSettings.selectedDesignID
        // Clamp any previously-saved value to the 5-minute floor.
        self.focusMinutes = min(180, max(5, AppSettings.focusMinutes))
        self.engine = TimerEngine()
        engine.config = TimerEngine.Config(
            sessionsBeforeLongBreak: AppSettings.sessionsBeforeLongBreak,
            idleResetGap: TimeInterval(AppSettings.idleResetMinutes * 60))

        restoreRunningStateIfNeeded()

        ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // .common mode keeps the menu bar countdown updating while menus or
        // the popover are open.
        RunLoop.main.add(ticker!, forMode: .common)

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    // MARK: - Tick

    func tick() {
        engine.config = TimerEngine.Config(
            sessionsBeforeLongBreak: AppSettings.sessionsBeforeLongBreak,
            idleResetGap: TimeInterval(AppSettings.idleResetMinutes * 60))
        remaining = engine.remaining()
        if let event = engine.tick() {
            handle(event)
        }
        phase = engine.phase
        onStatusUpdate?()
    }

    private func handle(_ event: TimerEngine.Event) {
        switch event {
        case .focusCompleted:
            completeFocusSession()
        case .breakEnded(let kind):
            logSession(kind: kind == .long ? .longBreak : .shortBreak, outcome: .completed)
            onOverlay?(.breakOver)
            if AppSettings.autoStartNextFocus {
                startFocus()
            }
        }
        persistRunningState()
    }

    private func completeFocusSession() {
        let before = totalBlocksBuilt
        let cell = effectiveTarget
        if let cell {
            worldFile.current.place(designID: selectedDesignID, isCracked: false,
                                    at: cell, date: Date())
            store.saveWorld(worldFile)
        }
        logSession(kind: .focus, outcome: .completed, designID: selectedDesignID, cell: cell)
        targetCell = nil

        if let unlocked = BlockDesign.newlyUnlocked(before: before, after: totalBlocksBuilt).first {
            unlockAnnouncement = unlocked
        }
        onOverlay?(.blockBuilt(currentDesign))

        if AppSettings.autoStartBreaks, case .breakPrompt = engine.phase {
            startBreak()
        }
    }

    // MARK: - User intents

    func startFocus() {
        guard case .idle = engine.phase else { return }
        editMode = .none
        currentSessionStart = Date()
        engine.startFocus(duration: TimeInterval(focusMinutes * 60))
        if targetCell == nil { targetCell = world.defaultTarget() }
        afterTransition()
    }

    func pause() { engine.pause(); afterTransition() }
    func resume() { engine.resume(); afterTransition() }

    func abandonFocus() {
        guard engine.phase.isFocus else { return }
        let cell = effectiveTarget
        if AppSettings.crackedBlockOnAbandon, let cell {
            worldFile.current.place(designID: BlockDesign.cracked.id, isCracked: true,
                                    at: cell, date: Date())
            store.saveWorld(worldFile)
        }
        engine.abandonFocus()
        logSession(kind: .focus, outcome: .abandoned, designID: selectedDesignID,
                   cell: AppSettings.crackedBlockOnAbandon ? cell : nil)
        targetCell = nil
        afterTransition()
    }

    func startBreak() {
        guard case .breakPrompt(let kind) = engine.phase else { return }
        currentSessionStart = Date()
        let minutes = kind == .long ? AppSettings.longBreakMinutes : AppSettings.shortBreakMinutes
        engine.startBreak(duration: TimeInterval(minutes * 60))
        afterTransition()
    }

    func skipBreak() {
        guard case .breakPrompt(let kind) = engine.phase else { return }
        engine.skipBreak()
        logSession(kind: kind == .long ? .longBreak : .shortBreak, outcome: .skipped)
        afterTransition()
    }

    func endBreakEarly() {
        guard engine.phase.isBreak else { return }
        let kind: BreakKind = {
            if case .breakRunning(let k, _) = engine.phase { return k }
            if case .breakPaused(let k, _) = engine.phase { return k }
            return .short
        }()
        engine.endBreakEarly()
        logSession(kind: kind == .long ? .longBreak : .shortBreak, outcome: .completed)
        afterTransition()
    }

    func selectDesign(_ design: BlockDesign) {
        guard isUnlocked(design) else { return }
        selectedDesignID = design.id
        AppSettings.selectedDesignID = design.id
    }

    /// Tap on the world. While a focus session runs, taps on valid cells
    /// move the placement target. While idle, taps also select existing
    /// blocks for editing (move/delete).
    func handleWorldTap(at cell: GridCell) {
        switch engine.phase {
        case .focusRunning, .focusPaused:
            if world.isValidPlacement(cell) { targetCell = cell }
        case .idle:
            handleIdleTap(cell)
        default:
            break
        }
    }

    private func handleIdleTap(_ cell: GridCell) {
        if case .moving(let source) = editMode {
            if world.validMoveDestinations(from: source).contains(cell) {
                worldFile.current.moveBlock(from: source, to: cell)
                store.saveWorld(worldFile)
                editMode = .none
                targetCell = nil
            } else if world.isOccupied(cell), cell != source {
                editMode = .selected(cell)
            } else {
                editMode = .none
            }
            return
        }
        if world.isOccupied(cell) {
            // Tapping the selected block again deselects it.
            editMode = editMode == .selected(cell) ? .none : .selected(cell)
        } else if world.isValidPlacement(cell) {
            editMode = .none
            targetCell = cell
        }
    }

    var selectedBlock: PlacedBlock? {
        switch editMode {
        case .selected(let cell), .moving(let cell):
            return world.block(at: cell)
        case .none:
            return nil
        }
    }

    func beginMovingSelectedBlock() {
        if case .selected(let cell) = editMode {
            editMode = .moving(cell)
        }
    }

    func deleteSelectedBlock() {
        guard case .selected(let cell) = editMode else { return }
        worldFile.current.removeBlock(at: cell)
        store.saveWorld(worldFile)
        editMode = .none
        targetCell = nil
    }

    func cancelWorldEdit() {
        editMode = .none
    }

    func startFreshCanvas() {
        guard !worldFile.current.blocks.isEmpty else { return }
        worldFile.archived.append(ArchivedWorld(archivedAt: Date(),
                                                blocks: worldFile.current.blocks))
        worldFile.current = World()
        targetCell = nil
        editMode = .none
        store.saveWorld(worldFile)
    }

    private func afterTransition() {
        phase = engine.phase
        remaining = engine.remaining()
        persistRunningState()
        onStatusUpdate?()
    }

    // MARK: - Logging

    private func logSession(kind: SessionKind, outcome: SessionOutcome,
                            designID: String? = nil, cell: GridCell? = nil) {
        let record = SessionRecord(
            startedAt: currentSessionStart ?? Date(),
            endedAt: Date(),
            plannedDuration: engine.plannedDuration,
            kind: kind,
            outcome: outcome,
            designID: designID,
            cell: cell)
        sessions.append(record)
        store.saveSessions(sessions)
        currentSessionStart = nil
    }

    // MARK: - Running-state persistence & restore

    private func persistRunningState() {
        let state: RunningState?
        switch engine.phase {
        case .idle:
            state = nil
        case .focusRunning(let end):
            state = runningState(.focusRunning, endDate: end)
        case .focusPaused(let remaining):
            state = runningState(.focusPaused, pausedRemaining: remaining)
        case .breakPrompt(let kind):
            state = runningState(.breakPrompt, breakKind: kind)
        case .breakRunning(let kind, let end):
            state = runningState(.breakRunning, breakKind: kind, endDate: end)
        case .breakPaused(let kind, let remaining):
            state = runningState(.breakPaused, breakKind: kind, pausedRemaining: remaining)
        }
        store.saveRunningState(state)
    }

    private func runningState(_ kind: RunningState.PhaseKind, breakKind: BreakKind? = nil,
                              endDate: Date? = nil,
                              pausedRemaining: TimeInterval? = nil) -> RunningState {
        RunningState(
            phaseKind: kind,
            breakKind: breakKind,
            endDate: endDate,
            pausedRemaining: pausedRemaining,
            plannedDuration: engine.plannedDuration,
            startedAt: currentSessionStart ?? Date(),
            designID: selectedDesignID,
            targetCell: targetCell,
            completedSinceLongBreak: engine.completedSinceLongBreak,
            lastFocusEndedAt: engine.lastFocusEndedAt)
    }

    private func restoreRunningStateIfNeeded() {
        guard let saved = store.loadRunningState() else { return }
        currentSessionStart = saved.startedAt
        if let designID = saved.designID { selectedDesignID = designID }
        targetCell = saved.targetCell

        let restoredPhase: TimerPhase
        switch saved.phaseKind {
        case .focusRunning:
            restoredPhase = .focusRunning(endDate: saved.endDate ?? Date())
        case .focusPaused:
            restoredPhase = .focusPaused(remaining: saved.pausedRemaining ?? 0)
        case .breakPrompt:
            restoredPhase = .breakPrompt(saved.breakKind ?? .short)
        case .breakRunning:
            restoredPhase = .breakRunning(kind: saved.breakKind ?? .short,
                                          endDate: saved.endDate ?? Date())
        case .breakPaused:
            restoredPhase = .breakPaused(kind: saved.breakKind ?? .short,
                                         remaining: saved.pausedRemaining ?? 0)
        }
        engine.restore(phase: restoredPhase,
                       plannedDuration: saved.plannedDuration,
                       completedSinceLongBreak: saved.completedSinceLongBreak,
                       lastFocusEndedAt: saved.lastFocusEndedAt)
        phase = engine.phase
        remaining = engine.remaining()
        // If the deadline passed while the app was closed, the first tick()
        // (scheduled below in init, and run once here) completes the session,
        // places the block, and shows the overlay exactly once.
        DispatchQueue.main.async { [weak self] in self?.tick() }
    }
}

extension TimeInterval {
    /// "MM:SS" (or "H:MM:SS" above an hour) for countdown displays.
    var countdownString: String {
        let total = Int(self.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
