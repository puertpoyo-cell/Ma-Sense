import Foundation

/// D6 위젯 요약 (SCREENS.md 위젯). 오늘 화면과 같은 규칙(R2·R13)으로 다음 투약, 마지막 부위, 남은 회차를 고른다.
/// 판단·추천 없이 사실만. 부위는 표시명으로 넘겨 위젯이 부위 목록을 따로 갖지 않게 한다
enum WidgetRules {
    /// - Parameters:
    ///   - doses: 활성 처방의 기록 (마디·남은 회차)
    ///   - allDoses: 모든 처방의 기록 (마지막 투약·부위는 몸 기준, R6)
    static func snapshot(
        prescription: PrescriptionSnapshot?,
        doses: [DoseSnapshot],
        allDoses: [DoseSnapshot],
        now: Date,
        calendar: Calendar,
        siteName: (BodySite) -> String = { $0.localizedName }
    ) -> WidgetSnapshot {
        let last = allDoses.filter { !$0.isCancelled }.max { $0.administeredAt < $1.administeredAt }
        var snapshot = WidgetSnapshot(
            phase: .noPrescription,
            scheduledDate: nil,
            lastDoseDate: last?.administeredAt,
            lastSiteName: last?.site.map(siteName),
            remainingDoses: nil,
            updatedAt: now
        )
        guard let p = prescription else { return snapshot }

        snapshot.remainingDoses = PrescriptionRules.remainingDoses(p: p, doses: doses)
        let cycles = CycleRules.cycles(for: p, doses: doses, now: now, until: .distantFuture, calendar: calendar)
        switch CycleRules.nextDose(cycles: cycles, doses: doses, now: now) {
        case let .due(cycle, _)?, let .overdue(cycle, _)?:
            snapshot.phase = .upcoming
            snapshot.scheduledDate = cycle.scheduledDate
        case let .done(_, next)?:
            // 마지막 회차를 기록했으면 다음 예정이 없다. 위젯은 "새 처방을 입력하세요"
            snapshot.phase = .done
            snapshot.scheduledDate = next?.scheduledDate
        case nil:
            snapshot.phase = .exhausted
        }
        return snapshot
    }
}
