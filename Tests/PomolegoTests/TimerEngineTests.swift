import XCTest

final class TimerEngineTests: XCTestCase {
    private var currentTime: Date!
    private var engine: TimerEngine!

    override func setUp() {
        super.setUp()
        currentTime = Date(timeIntervalSinceReferenceDate: 1_000_000)
        engine = TimerEngine(now: { self.currentTime })
        engine.config = TimerEngine.Config(sessionsBeforeLongBreak: 4,
                                           idleResetGap: 2 * 3600)
    }

    private func advance(_ seconds: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(seconds)
    }

    private func completeFocusSession(duration: TimeInterval = 25 * 60) -> TimerEngine.Event? {
        engine.startFocus(duration: duration)
        advance(duration)
        return engine.tick()
    }

    // MARK: - Basic flow

    func testStartFocusCountsDown() {
        engine.startFocus(duration: 25 * 60)
        XCTAssertEqual(engine.remaining(), 25 * 60, accuracy: 0.1)
        advance(60)
        XCTAssertEqual(engine.remaining(), 24 * 60, accuracy: 0.1)
        XCTAssertNil(engine.tick())
    }

    func testFocusCompletionProposesShortBreak() {
        let event = completeFocusSession()
        XCTAssertEqual(event, .focusCompleted(proposedBreak: .short))
        XCTAssertEqual(engine.phase, .breakPrompt(.short))
    }

    func testCannotStartFocusWhileRunning() {
        engine.startFocus(duration: 25 * 60)
        let end = engine.phase
        engine.startFocus(duration: 10 * 60)
        XCTAssertEqual(engine.phase, end)
    }

    // MARK: - Long break cadence

    func testFourthSessionProposesLongBreak() {
        for index in 1...4 {
            let event = completeFocusSession()
            let expected: BreakKind = index == 4 ? .long : .short
            XCTAssertEqual(event, .focusCompleted(proposedBreak: expected),
                           "session \(index)")
            if index < 4 {
                engine.skipBreak()
            }
        }
    }

    func testLongBreakTakenResetsCycle() {
        for _ in 1...3 {
            _ = completeFocusSession()
            engine.skipBreak()
        }
        _ = completeFocusSession()
        engine.startBreak(duration: 20 * 60)
        advance(20 * 60)
        XCTAssertEqual(engine.tick(), .breakEnded(.long))
        XCTAssertEqual(engine.completedSinceLongBreak, 0)
        // Next completion proposes a short break again.
        XCTAssertEqual(completeFocusSession(), .focusCompleted(proposedBreak: .short))
    }

    func testSkippingLongBreakAlsoResetsCycle() {
        for _ in 1...4 {
            _ = completeFocusSession()
            engine.skipBreak()
        }
        XCTAssertEqual(engine.completedSinceLongBreak, 0)
        XCTAssertEqual(completeFocusSession(), .focusCompleted(proposedBreak: .short))
    }

    func testIdleGapResetsCycle() {
        for _ in 1...3 {
            _ = completeFocusSession()
            engine.skipBreak()
        }
        advance(3 * 3600) // beyond the 2 h idle gap
        // This would have been the 4th consecutive session.
        XCTAssertEqual(completeFocusSession(), .focusCompleted(proposedBreak: .short))
    }

    // MARK: - Pause / resume

    func testPauseFreezesRemainingAndResumeRecomputesEndDate() {
        engine.startFocus(duration: 25 * 60)
        advance(5 * 60)
        engine.pause()
        advance(60 * 60) // an hour passes while paused
        XCTAssertEqual(engine.remaining(), 20 * 60, accuracy: 0.1)
        XCTAssertNil(engine.tick())
        engine.resume()
        advance(20 * 60)
        XCTAssertEqual(engine.tick(), .focusCompleted(proposedBreak: .short))
    }

    func testPauseDuringBreak() {
        _ = completeFocusSession()
        engine.startBreak(duration: 5 * 60)
        advance(2 * 60)
        engine.pause()
        advance(30 * 60)
        XCTAssertEqual(engine.remaining(), 3 * 60, accuracy: 0.1)
        engine.resume()
        advance(3 * 60)
        XCTAssertEqual(engine.tick(), .breakEnded(.short))
    }

    // MARK: - Abandon

    func testAbandonReturnsToIdleWithoutCountingSession() {
        engine.startFocus(duration: 25 * 60)
        advance(10 * 60)
        engine.abandonFocus()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.completedSinceLongBreak, 0)
    }

    // MARK: - Clock edge cases

    func testClockJumpBackwardClampsRemainingToPlannedDuration() {
        engine.startFocus(duration: 25 * 60)
        advance(-2 * 3600) // user sets the clock back two hours
        XCTAssertEqual(engine.remaining(), 25 * 60, accuracy: 0.1)
    }

    func testDeadlinePassedWhileAsleepCompletesOnNextTick() {
        engine.startFocus(duration: 25 * 60)
        advance(8 * 3600) // Mac slept through the whole session
        XCTAssertEqual(engine.tick(), .focusCompleted(proposedBreak: .short))
        XCTAssertEqual(engine.remaining(), 0)
    }

    // MARK: - Restore

    func testRestorePastDeadlineCompletesOnFirstTick() {
        let pastEnd = currentTime.addingTimeInterval(-300)
        engine.restore(phase: .focusRunning(endDate: pastEnd),
                       plannedDuration: 25 * 60,
                       completedSinceLongBreak: 2,
                       lastFocusEndedAt: nil)
        XCTAssertEqual(engine.tick(), .focusCompleted(proposedBreak: .short))
        XCTAssertEqual(engine.completedSinceLongBreak, 3)
    }

    func testRestoreRunningSessionContinuesCountdown() {
        let futureEnd = currentTime.addingTimeInterval(600)
        engine.restore(phase: .focusRunning(endDate: futureEnd),
                       plannedDuration: 25 * 60,
                       completedSinceLongBreak: 0,
                       lastFocusEndedAt: nil)
        XCTAssertNil(engine.tick())
        XCTAssertEqual(engine.remaining(), 600, accuracy: 0.1)
    }
}
