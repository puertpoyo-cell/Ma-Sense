import Foundation

/// 마디(Cycle). 투약 1회를 기준으로 한 주 단위 (RULES.md R1).
struct Cycle: Equatable, Identifiable {
    /// 0부터
    let index: Int
    /// 예정 일시
    let scheduledDate: Date
    /// `[scheduledDate - 2일, scheduledDate + intervalDays - 2일)`. 예정일 이틀 전부터 그 마디로 본다
    let interval: DateInterval

    var id: Int { index }

    func contains(_ date: Date) -> Bool {
        // DateInterval.contains는 end를 포함하므로 반열림 구간으로 직접 비교한다
        date >= interval.start && date < interval.end
    }
}

/// R2. 홈 카운트다운 상태
enum NextDose: Equatable {
    /// 현재 마디에 기록이 없고 예정 시각 전
    case due(Cycle, remaining: TimeInterval)
    /// 현재 마디에 기록이 없고 예정 시각이 지남. UI 문구는 "예정일이 지났습니다" (질책 없음)
    case overdue(Cycle, elapsed: TimeInterval)
    /// 현재 마디에 기록이 있음
    case done(Cycle, next: Cycle?)
}

enum CycleRules {
    /// 예정일 며칠 전부터 그 마디로 보는지
    static let leadDays = 2
    /// 무한 루프 방지. 주 1회 기준 약 20년
    private static let hardCap = 1_000

    /// R1. 첫 마디 예정일. `startDate` 당일 또는 그 이후 첫 `scheduledWeekday`의 `scheduledTime`.
    /// 시작일이 예정 요일과 같은 날이면 그날이 첫 마디다.
    static func firstScheduledDate(for p: PrescriptionSnapshot, calendar: Calendar) -> Date? {
        guard (1...7).contains(p.scheduledWeekday) else { return nil }
        let startDay = calendar.startOfDay(for: p.startDate)
        let startWeekday = calendar.component(.weekday, from: startDay)
        let delta = (p.scheduledWeekday - startWeekday + 7) % 7
        guard let day = calendar.date(byAdding: .day, value: delta, to: startDay) else { return nil }
        return calendar.date(
            bySettingHour: p.scheduledHour,
            minute: p.scheduledMinute,
            second: 0,
            of: day
        )
    }

    /// R1. 마디 목록.
    ///
    /// - 이후 마디는 첫 마디 + `intervalDays * index` (누적 오차 없음)
    /// - 처방이 소진되면 그 이후 마디는 만들지 않는다. 소진 판정은 투약 수가 아니라 "쓰인 회차"로 한다:
    ///   기록이 있는 마디와 현재·미래 마디는 회차를 1개씩 쓰고, 지나간 누락 마디는 쓰지 않는다.
    ///   그래서 누락이 있으면 마디가 그만큼 뒤로 늘어난다
    /// - `until`은 `scheduledDate` 상한. 전체를 원하면 `.distantFuture`를 넘긴다 (회차 수로 끝난다)
    static func cycles(
        for p: PrescriptionSnapshot,
        doses: [DoseSnapshot],
        now: Date,
        until end: Date,
        calendar: Calendar
    ) -> [Cycle] {
        guard p.intervalDays >= leadDays + 1, p.totalDoses > 0,
              let first = firstScheduledDate(for: p, calendar: calendar),
              let firstStart = calendar.date(byAdding: .day, value: -leadDays, to: first)
        else { return [] }

        let active = doses.filter { !$0.isCancelled }
        // 첫 마디 구간 전에 맞은 기록도 회차를 쓴다
        var budget = p.totalDoses - active.filter { $0.administeredAt < firstStart }.count
        var result: [Cycle] = []
        var index = 0

        while budget > 0, index < hardCap {
            guard let scheduled = calendar.date(byAdding: .day, value: p.intervalDays * index, to: first),
                  scheduled <= end,
                  let start = calendar.date(byAdding: .day, value: -leadDays, to: scheduled),
                  let finish = calendar.date(byAdding: .day, value: p.intervalDays - leadDays, to: scheduled),
                  finish > start
            else { break }

            let cycle = Cycle(index: index, scheduledDate: scheduled, interval: DateInterval(start: start, end: finish))
            result.append(cycle)

            let used = active.filter { cycle.contains($0.administeredAt) }.count
            if used > 0 {
                budget -= used
            } else if finish > now {
                // 현재 또는 미래 마디: 회차 1개 예약
                budget -= 1
            }
            // 지나간 누락 마디는 회차를 쓰지 않는다 (R3)
            index += 1
        }
        return result
    }

    /// 마디 구간 안의 취소되지 않은 기록. 여러 개면 투약 시각 순
    static func doses(in cycle: Cycle, from doses: [DoseSnapshot]) -> [DoseSnapshot] {
        doses
            .filter { !$0.isCancelled && cycle.contains($0.administeredAt) }
            .sorted { $0.administeredAt < $1.administeredAt }
    }

    /// `date`를 포함하는 마디
    static func cycle(containing date: Date, in cycles: [Cycle]) -> Cycle? {
        cycles.first { $0.contains(date) }
    }

    /// R2. 다음 투약과 카운트다운. 처방 소진 후(`cycles`가 모두 지남)에는 `nil`.
    static func nextDose(cycles: [Cycle], doses: [DoseSnapshot], now: Date) -> NextDose? {
        guard let first = cycles.first else { return nil }

        if now < first.interval.start {
            return .due(first, remaining: first.scheduledDate.timeIntervalSince(now))
        }
        guard let current = cycle(containing: now, in: cycles) else {
            // 모든 마디가 지났다 = 처방 소진
            return nil
        }
        if !Self.doses(in: current, from: doses).isEmpty {
            let next = cycles.first { $0.index == current.index + 1 }
            return .done(current, next: next)
        }
        if now < current.scheduledDate {
            return .due(current, remaining: current.scheduledDate.timeIntervalSince(now))
        }
        return .overdue(current, elapsed: now.timeIntervalSince(current.scheduledDate))
    }

    /// R3. 누락 마디. 구간이 끝났는데 취소되지 않은 기록이 없는 마디. 저장하지 않고 항상 계산한다.
    static func missedCycles(cycles: [Cycle], doses: [DoseSnapshot], now: Date) -> [Cycle] {
        cycles.filter { cycle in
            cycle.interval.end <= now && Self.doses(in: cycle, from: doses).isEmpty
        }
    }

    /// 예정일이 지금까지 온 마디. 보관된 처방은 다음 처방 시작(`nextStart`) 전까지만 본다.
    /// 처방을 바꾼 뒤에도 이전 처방의 마디가 계속 이어져 누락으로 쌓이지 않게 하려는 것 (기록 탭·리포트 공용).
    static func pastCycles(
        for p: PrescriptionSnapshot,
        doses: [DoseSnapshot],
        nextStart: Date?,
        now: Date,
        calendar: Calendar
    ) -> [Cycle] {
        let end = nextStart.map { min($0, now) } ?? now
        return cycles(for: p, doses: doses, now: now, until: end, calendar: calendar)
            .filter { $0.scheduledDate < end || end == now }
    }
}
