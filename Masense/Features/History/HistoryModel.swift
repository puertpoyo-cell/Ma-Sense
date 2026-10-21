import Foundation

/// S4 기록 탭 목록 구성. 사실만 나열하고 평가하지 않는다.
enum HistoryModel {
    // MARK: 투약

    struct DoseRow: Identifiable, Equatable {
        enum Kind: Equatable {
            case dose(id: UUID, site: BodySite, sequence: Int, hasNote: Bool, isCancelled: Bool)
            /// 구간이 끝났는데 기록이 없는 마디 (R3). `canAddDose`는 현재 처방의 마디라 과거 기록을 더할 수 있는지
            case missed(scheduled: Date, canAddDose: Bool)
        }

        let id: String
        let date: Date
        let kind: Kind
    }

    struct Month: Identifiable, Equatable {
        let start: Date
        let rows: [DoseRow]
        var id: Date { start }
    }

    struct PrescriptionHistory {
        let prescription: PrescriptionSnapshot
        let doses: [DoseSnapshot]
        let isActive: Bool
    }

    /// 월별 투약 행, 최근 순. 누락 마디는 회색 점선 행으로 섞어 넣는다.
    /// 보관된 처방은 다음 처방 시작 전까지의 마디만 본다 (그 뒤의 누락을 만들지 않기 위해).
    static func doseMonths(_ histories: [PrescriptionHistory], now: Date, calendar: Calendar) -> [Month] {
        let ordered = histories.sorted { $0.prescription.startDate < $1.prescription.startDate }
        var rows: [DoseRow] = []

        for (offset, history) in ordered.enumerated() {
            let nextStart = offset + 1 < ordered.count ? ordered[offset + 1].prescription.startDate : nil
            let cycles = CycleRules.pastCycles(
                for: history.prescription,
                doses: history.doses,
                nextStart: nextStart,
                now: now,
                calendar: calendar
            )
            let missed = CycleRules.missedCycles(cycles: cycles, doses: history.doses, now: now)
            rows += missed.map { cycle in
                DoseRow(
                    id: "missed.\(offset).\(cycle.index)",
                    date: cycle.scheduledDate,
                    kind: .missed(scheduled: cycle.scheduledDate, canAddDose: history.isActive)
                )
            }
            rows += history.doses.map { dose in
                DoseRow(
                    id: dose.id.uuidString,
                    date: dose.administeredAt,
                    kind: .dose(
                        id: dose.id,
                        site: dose.site,
                        sequence: dose.sequence,
                        hasNote: !(dose.note ?? "").isEmpty,
                        isCancelled: dose.isCancelled
                    )
                )
            }
        }

        rows.sort { $0.date > $1.date }
        var months: [Month] = []
        for row in rows {
            let start = calendar.dateInterval(of: .month, for: row.date)?.start ?? row.date
            if let last = months.last, last.start == start {
                months[months.count - 1] = Month(start: start, rows: last.rows + [row])
            } else {
                months.append(Month(start: start, rows: [row]))
            }
        }
        return months
    }

    // MARK: 컨디션

    struct ConditionSlot: Equatable {
        enum State: Equatable {
            case recorded(symptomCount: Int, maxSeverity: Int, appetite: AppetiteLevel)
            /// 기록 없음. 창이 열려 있거나 지났으므로 "지난 체크"로 더할 수 있다 (R5)
            case missing
        }

        let window: ConditionWindow
        let state: State
    }

    struct ConditionGroup: Identifiable, Equatable {
        let doseID: UUID
        let administeredAt: Date
        /// 아직 열리지 않은 창(투약 후 12h·36h 전)은 넣지 않는다
        let slots: [ConditionSlot]
        var id: UUID { doseID }
    }

    /// 투약별 24h·48h 요약, 최근 투약 순. 취소된 투약은 제외.
    static func conditionGroups(doses: [DoseSnapshot], checks: [ConditionCheckSnapshot], now: Date) -> [ConditionGroup] {
        doses
            .filter { !$0.isCancelled }
            .sorted { $0.administeredAt > $1.administeredAt }
            .compactMap { dose in
                let slots: [ConditionSlot] = ConditionWindow.allCases.compactMap { window in
                    let opensAt = dose.administeredAt.addingTimeInterval(openOffset(window))
                    let latest = checks
                        .filter { $0.doseID == dose.id && $0.window == window }
                        .max { $0.checkedAt < $1.checkedAt }
                    if let latest {
                        return ConditionSlot(
                            window: window,
                            state: .recorded(
                                symptomCount: latest.symptoms.filter { $0.severity > 0 }.count,
                                maxSeverity: latest.symptoms.map(\.severity).max() ?? 0,
                                appetite: latest.appetite
                            )
                        )
                    }
                    return now >= opensAt ? ConditionSlot(window: window, state: .missing) : nil
                }
                return slots.isEmpty ? nil : ConditionGroup(doseID: dose.id, administeredAt: dose.administeredAt, slots: slots)
            }
    }

    private static func openOffset(_ window: ConditionWindow) -> TimeInterval {
        switch window {
        case .h24: return ConditionRules.h24Window.lowerBound
        case .h48: return ConditionRules.h48Window.lowerBound
        }
    }
}
