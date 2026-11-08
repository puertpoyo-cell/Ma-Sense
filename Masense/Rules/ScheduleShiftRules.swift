import Foundation

/// D45 투약 일정 옮기기 (2026-11-08 사람 요청 "주기 조정이랑 먼저 맞은 거 수정하는 게 어렵다, 하루 맞는 게 늦었는데 변경이 어려웠어").
/// 예정보다 늦거나 일찍 맞았을 때 다음부터 그 요일로 맞추는 것은 사용자가 고른다. 앱은 권하거나 판단하지 않는다
/// (의사와 정한 일정에 맞춰 고르도록 안내만, COMPLIANCE.md). 스키마는 그대로, 처방의 요일·시각(필요하면 시작일)만 바꾼다
enum ScheduleShiftRules {
    /// 투약 시각이 속한 마디의 예정일과 며칠 차이 (+ 늦게, - 일찍, 0 같은 날). 어느 마디에도 없으면 nil
    static func dayOffset(administeredAt: Date, prescription: PrescriptionSnapshot, doses: [DoseSnapshot], calendar: Calendar) -> Int? {
        let others = doses.filter { $0.administeredAt != administeredAt }
        let cycles = CycleRules.cycles(for: prescription, doses: others, now: administeredAt, until: administeredAt.addingTimeInterval(8 * 86_400), calendar: calendar)
        guard let cycle = CycleRules.cycle(containing: administeredAt, in: cycles) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: cycle.scheduledDate), to: calendar.startOfDay(for: administeredAt)).day
    }

    /// 새 요일·시각을 적용한 처방. 지난 기록이 한 마디에 둘 이상 들어가거나 마디 밖으로 빠지면,
    /// 처방 시작일을 `anchor` 날로 옮겨 그날부터 새 요일로 센다 (지난 기록의 회차는 그대로 남는다)
    static func shifted(
        _ p: PrescriptionSnapshot,
        doses: [DoseSnapshot],
        weekday: Int,
        hour: Int,
        minute: Int,
        anchor: Date,
        calendar: Calendar
    ) -> PrescriptionSnapshot {
        let candidate = copy(p, startDate: p.startDate, weekday: weekday, hour: hour, minute: minute)
        if isConsistent(candidate, doses: doses, calendar: calendar) { return candidate }
        return copy(p, startDate: calendar.startOfDay(for: anchor), weekday: weekday, hour: hour, minute: minute)
    }

    /// 취소하지 않은 기록이 모두 서로 다른 마디 안에 있다 (첫 마디 전 기록은 회차만 쓰므로 뺀다)
    static func isConsistent(_ p: PrescriptionSnapshot, doses: [DoseSnapshot], calendar: Calendar) -> Bool {
        let active = doses.filter { !$0.isCancelled }
        guard let last = active.map(\.administeredAt).max(),
              let first = CycleRules.firstScheduledDate(for: p, calendar: calendar),
              let firstStart = calendar.date(byAdding: .day, value: -CycleRules.leadDays, to: first)
        else { return true }
        let inRange = active.filter { $0.administeredAt >= firstStart }
        let cycles = CycleRules.cycles(
            for: copy(p, startDate: p.startDate, weekday: p.scheduledWeekday, hour: p.scheduledHour, minute: p.scheduledMinute, total: 10_000),
            doses: active, now: last, until: last.addingTimeInterval(8 * 86_400), calendar: calendar
        )
        var seen = Set<Int>()
        for dose in inRange {
            guard let cycle = CycleRules.cycle(containing: dose.administeredAt, in: cycles), seen.insert(cycle.index).inserted else { return false }
        }
        return true
    }

    /// 미리 보기: 이 처방에서 아직 기록이 없는 다음 예정 일시 (지금 이후에 끝나는 마디 중 첫 번째)
    static func upcoming(_ p: PrescriptionSnapshot, doses: [DoseSnapshot], now: Date, calendar: Calendar) -> Date? {
        let active = doses.filter { !$0.isCancelled }
        let cycles = CycleRules.cycles(for: p, doses: active, now: now, until: now.addingTimeInterval(22 * 86_400), calendar: calendar)
        return cycles.first { cycle in
            cycle.interval.end > now && !active.contains { cycle.contains($0.administeredAt) }
        }?.scheduledDate
    }

    private static func copy(_ p: PrescriptionSnapshot, startDate: Date, weekday: Int, hour: Int, minute: Int, total: Int? = nil) -> PrescriptionSnapshot {
        PrescriptionSnapshot(
            startDate: startDate,
            scheduledWeekday: weekday,
            scheduledHour: hour,
            scheduledMinute: minute,
            dosesPerPen: p.dosesPerPen,
            totalDoses: total ?? p.totalDoses,
            nextClinicDate: p.nextClinicDate,
            endDate: p.endDate,
            doseLabel: p.doseLabel
        )
    }
}
