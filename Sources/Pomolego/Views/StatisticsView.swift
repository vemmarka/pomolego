import SwiftUI
import Charts

/// Statistics live in their own resizable window. Every number here is
/// derived from the append-only session log.
struct StatisticsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let stats = Statistics(sessions: state.sessions)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                todaySection(stats)
                Divider()
                chartSection(title: "Focus minutes — last 14 days") {
                    focusMinutesChart(stats)
                }
                chartSection(title: "Blocks by design") {
                    designBreakdownChart(stats)
                }
                chartSection(title: "Completed vs abandoned — last 14 days") {
                    outcomeChart(stats)
                }
                Divider()
                streaksSection(stats)
                allTimeSection(stats)
                collectionSection(stats)
            }
            .padding(20)
        }
        .frame(minWidth: 480, minHeight: 480)
    }

    // MARK: - Sections

    private func todaySection(_ stats: Statistics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today").font(.title2.bold())
            HStack(spacing: 12) {
                statCard("Blocks built", "\(stats.blocksToday)")
                statCard("Focus minutes", "\(stats.focusMinutesToday)")
                statCard("Abandoned", "\(stats.abandonedToday)")
                statCard("Breaks taken", "\(stats.breaksToday)")
            }
        }
    }

    private func chartSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
                .frame(height: 160)
        }
    }

    private func focusMinutesChart(_ stats: Statistics) -> some View {
        Chart(stats.last14Days, id: \.day) { entry in
            BarMark(
                x: .value("Day", entry.day, unit: .day),
                y: .value("Minutes", entry.focusMinutes))
            .foregroundStyle(Color.accentColor)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) {
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                AxisGridLine()
            }
        }
    }

    private func designBreakdownChart(_ stats: Statistics) -> some View {
        Chart(stats.designCounts, id: \.design.id) { entry in
            BarMark(
                x: .value("Blocks", entry.count),
                y: .value("Design", entry.design.name))
            .foregroundStyle(entry.design.baseColor)
        }
    }

    private func outcomeChart(_ stats: Statistics) -> some View {
        Chart(stats.outcomesByDay, id: \.id) { entry in
            BarMark(
                x: .value("Day", entry.day, unit: .day),
                y: .value("Sessions", entry.count))
            .foregroundStyle(by: .value("Outcome", entry.outcome))
        }
        .chartForegroundStyleScale([
            "Completed": Color.green,
            "Abandoned": Color.red.opacity(0.75),
        ])
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) {
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                AxisGridLine()
            }
        }
    }

    private func streaksSection(_ stats: Statistics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streaks").font(.headline)
            HStack(spacing: 12) {
                statCard("Current streak",
                         "\(stats.currentStreak) day\(stats.currentStreak == 1 ? "" : "s")")
                statCard("Best streak",
                         "\(stats.bestStreak) day\(stats.bestStreak == 1 ? "" : "s")")
            }
        }
    }

    private func allTimeSection(_ stats: Statistics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All time").font(.headline)
            HStack(spacing: 12) {
                statCard("Blocks", "\(stats.totalBlocks)")
                statCard("Focus hours", String(format: "%.1f", stats.totalFocusHours))
                statCard("Completion rate", stats.completionRateText)
            }
        }
    }

    private func collectionSection(_ stats: Statistics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collection").font(.headline)
            let unlocked = BlockDesign.unlocked(totalBlocksBuilt: stats.totalBlocks).count
            Text("\(unlocked) of \(BlockDesign.catalog.count) designs unlocked")
                .foregroundStyle(.secondary)
            if let next = BlockDesign.nextUnlock(totalBlocksBuilt: stats.totalBlocks) {
                let previous = BlockDesign.catalog
                    .filter { $0.unlockAt <= stats.totalBlocks }
                    .map(\.unlockAt).max() ?? 0
                let span = max(1, next.unlockAt - previous)
                let into = stats.totalBlocks - previous
                ProgressView(value: Double(into), total: Double(span)) {
                    Text("Next: \(next.name) at \(next.unlockAt) blocks (\(next.unlockAt - stats.totalBlocks) to go)")
                        .font(.caption)
                }
            } else {
                Text("Everything unlocked — the observatory is yours. 🔭")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Derivations

private struct Statistics {
    struct DayMinutes { let day: Date; let focusMinutes: Int }
    struct DesignCount { let design: BlockDesign; let count: Int }
    struct OutcomeDay { let id: String; let day: Date; let outcome: String; let count: Int }

    let blocksToday: Int
    let focusMinutesToday: Int
    let abandonedToday: Int
    let breaksToday: Int
    let last14Days: [DayMinutes]
    let designCounts: [DesignCount]
    let outcomesByDay: [OutcomeDay]
    let currentStreak: Int
    let bestStreak: Int
    let totalBlocks: Int
    let totalFocusHours: Double
    let completionRateText: String

    init(sessions: [SessionRecord], calendar: Calendar = .current, today: Date = Date()) {
        let completed = sessions.completedFocus
        let abandoned = sessions.abandonedFocus

        blocksToday = completed.filter { calendar.isDate($0.endedAt, inSameDayAs: today) }.count
        focusMinutesToday = sessions.focusMinutes(on: today, calendar: calendar)
        abandonedToday = abandoned.filter { calendar.isDate($0.endedAt, inSameDayAs: today) }.count
        breaksToday = sessions.filter {
            ($0.kind == .shortBreak || $0.kind == .longBreak)
                && $0.outcome == .completed
                && calendar.isDate($0.endedAt, inSameDayAs: today)
        }.count

        let days = (0..<14).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: today))
        }.reversed()

        last14Days = days.map { day in
            DayMinutes(day: day, focusMinutes: sessions.focusMinutes(on: day, calendar: calendar))
        }

        let countsByDesign = Dictionary(grouping: completed, by: { $0.designID ?? "brick" })
        designCounts = countsByDesign
            .map { DesignCount(design: BlockDesign.design(for: $0.key), count: $0.value.count) }
            .sorted { $0.count > $1.count }

        outcomesByDay = days.flatMap { day -> [OutcomeDay] in
            let completedCount = completed.filter { calendar.isDate($0.endedAt, inSameDayAs: day) }.count
            let abandonedCount = abandoned.filter { calendar.isDate($0.endedAt, inSameDayAs: day) }.count
            let dayKey = day.timeIntervalSinceReferenceDate.description
            return [
                OutcomeDay(id: "c\(dayKey)", day: day, outcome: "Completed", count: completedCount),
                OutcomeDay(id: "a\(dayKey)", day: day, outcome: "Abandoned", count: abandonedCount),
            ]
        }

        // Streaks: consecutive days with at least one completed block.
        let daysWithBlocks = Set(completed.map { calendar.startOfDay(for: $0.endedAt) })
        var current = 0
        var probe = calendar.startOfDay(for: today)
        // Today doesn't break the streak if it has no block yet.
        if !daysWithBlocks.contains(probe) {
            probe = calendar.date(byAdding: .day, value: -1, to: probe) ?? probe
        }
        while daysWithBlocks.contains(probe) {
            current += 1
            probe = calendar.date(byAdding: .day, value: -1, to: probe) ?? probe
        }
        currentStreak = current

        var best = 0
        for day in daysWithBlocks {
            let previous = calendar.date(byAdding: .day, value: -1, to: day)
            guard let previous, !daysWithBlocks.contains(previous) else { continue }
            var length = 0
            var cursor = day
            while daysWithBlocks.contains(cursor) {
                length += 1
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            best = max(best, length)
        }
        bestStreak = max(best, current)

        totalBlocks = completed.count
        totalFocusHours = completed.reduce(0) { $0 + $1.plannedDuration } / 3600
        let attempts = completed.count + abandoned.count
        completionRateText = attempts == 0
            ? "—"
            : "\(Int((Double(completed.count) / Double(attempts) * 100).rounded()))%"
    }
}
