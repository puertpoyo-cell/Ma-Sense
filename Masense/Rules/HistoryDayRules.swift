import Foundation

/// 기록 탭 날짜 중심 보기 (D20). 주 달력의 날마다 "무엇을 기록했는지"만 표시한다.
/// 많고 적음·잘함/못함 판단 없음, 빈 날은 비어 있을 뿐 (COMPLIANCE.md 2.1-4, R3)
struct DayMarks: Equatable {
    var dose = false
    var condition = false
    var weight = false
    var protein = false
    var exercise = false
    var clinic = false

    var isEmpty: Bool { !(dose || condition || weight || protein || exercise || clinic) }
}

enum HistoryDayRules {
    /// `date`가 든 주의 7일 (달력 firstWeekday부터), 각 날 00:00
    static func week(containing date: Date, calendar: Calendar) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [calendar.startOfDay(for: date)] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    /// `date`가 든 달의 달력 칸 (N-E1). 주 단위 7칸씩, 그 달이 아닌 칸은 nil. 달력 firstWeekday부터
    static func monthGrid(containing date: Date, calendar: Calendar) -> [[Date?]] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        var rows: [[Date?]] = []
        var cursor = firstWeek.start
        while cursor < month.end {
            let row: [Date?] = (0..<7).map { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: cursor) else { return nil }
                return month.contains(day) ? day : nil
            }
            rows.append(row)
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return rows
    }

    /// 달을 `offset`만큼 옮긴 달의 1일
    static func shiftMonth(_ date: Date, by offset: Int, calendar: Calendar) -> Date {
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? date
        return calendar.date(byAdding: .month, value: offset, to: start) ?? date
    }

    /// 주를 `offset`만큼 옮긴 날 (같은 요일)
    static func shiftWeek(_ date: Date, by offset: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .weekOfYear, value: offset, to: date) ?? date
    }

    static func marks(
        on day: Date,
        doses: [DoseSnapshot],
        checks: [ConditionCheckSnapshot],
        weights: [WeightSampleSnapshot],
        proteins: [ProteinEntrySnapshot],
        sessions: [StrengthSessionSnapshot],
        visits: [Date] = [],
        calendar: Calendar
    ) -> DayMarks {
        let same = { (date: Date) in calendar.isDate(date, inSameDayAs: day) }
        return DayMarks(
            dose: doses.contains { !$0.isCancelled && same($0.administeredAt) },
            condition: checks.contains { same($0.checkedAt) },
            weight: weights.contains { same($0.measuredAt) },
            protein: proteins.contains { same($0.date) },
            exercise: sessions.contains { same($0.startedAt) },
            clinic: visits.contains { same($0) }
        )
    }
}
