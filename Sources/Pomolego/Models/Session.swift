import Foundation

enum SessionKind: String, Codable {
    case focus
    case shortBreak
    case longBreak
}

enum SessionOutcome: String, Codable {
    case completed
    case abandoned
    case skipped
}

/// One entry in the append-only session log. All statistics derive from
/// these records — never from counters that could drift.
struct SessionRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var startedAt: Date
    var endedAt: Date
    var plannedDuration: TimeInterval
    var kind: SessionKind
    var outcome: SessionOutcome
    var designID: String?
    var cell: GridCell?
}

extension Array where Element == SessionRecord {
    var completedFocus: [SessionRecord] {
        filter { $0.kind == .focus && $0.outcome == .completed }
    }

    var abandonedFocus: [SessionRecord] {
        filter { $0.kind == .focus && $0.outcome == .abandoned }
    }

    /// Total completed blocks ever — drives design unlocks.
    var totalBlocksBuilt: Int { completedFocus.count }

    func focusMinutes(on day: Date, calendar: Calendar = .current) -> Int {
        let inDay = completedFocus.filter { calendar.isDate($0.endedAt, inSameDayAs: day) }
        return Int(inDay.reduce(0) { $0 + $1.plannedDuration } / 60)
    }
}
