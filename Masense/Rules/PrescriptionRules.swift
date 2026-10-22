import Foundation

/// R13. 처방 소진 추정과 회차 계산.
enum PrescriptionRules {
    /// 취소되지 않은 기록 수
    static func usedDoses(_ doses: [DoseSnapshot]) -> Int {
        doses.filter { !$0.isCancelled }.count
    }

    static func remainingDoses(p: PrescriptionSnapshot, doses: [DoseSnapshot]) -> Int {
        max(p.totalDoses - usedDoses(doses), 0)
    }

    /// 새 기록의 회차 (1부터). 사용자가 수정할 수 있다
    static func nextSequence(doses: [DoseSnapshot]) -> Int {
        usedDoses(doses) + 1
    }

    /// "n회차 (펜 m의 k번째)". `pen`·`position` 모두 1부터
    static func penPosition(sequence: Int, dosesPerPen: Int) -> (pen: Int, position: Int) {
        guard dosesPerPen > 0, sequence > 0 else { return (pen: 1, position: max(sequence, 1)) }
        return (pen: (sequence - 1) / dosesPerPen + 1, position: (sequence - 1) % dosesPerPen + 1)
    }

    /// 소진 예상일. 남은 회차가 0이면 nil. 그 외에는 남은 회차를 모두 쓰는 마지막 마디의 예정일.
    static func exhaustionEstimate(
        p: PrescriptionSnapshot,
        doses: [DoseSnapshot],
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard remainingDoses(p: p, doses: doses) > 0 else { return nil }
        // CycleRules.cycles는 회차가 소진되는 마디에서 멈추므로 마지막 마디가 곧 소진 마디다
        return CycleRules.cycles(for: p, doses: doses, now: now, until: .distantFuture, calendar: calendar)
            .last?.scheduledDate
    }

    // MARK: 처방 전환 타임라인 (main C)

    /// 기간과 겹치는 처방을 시작일 오름차순으로. 기간 시작 전에 시작한 처방은 `isFirstInPeriod`.
    /// `endDate`는 그날 하루 끝까지 유효로 본다. 라벨은 공백만 있으면 nil (UI는 "처방 변경")
    static func prescriptionTimeline(all: [PrescriptionSnapshot], in period: DateInterval, calendar: Calendar) -> [PrescriptionMarker] {
        all
            .filter { p in
                guard p.startDate <= period.end else { return false }
                guard let endDate = p.endDate else { return true }
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
                return endOfDay > period.start
            }
            .sorted { $0.startDate < $1.startDate }
            .map { p in
                let label = p.doseLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
                return PrescriptionMarker(
                    startDate: p.startDate,
                    label: label?.isEmpty == false ? label : nil,
                    isFirstInPeriod: p.startDate < period.start
                )
            }
    }

    /// 기간 안의 처방 전환 횟수. 이어진 처방 사이의 경계 수라서 마커 수 - 1
    static func transitionCount(_ markers: [PrescriptionMarker]) -> Int {
        max(markers.count - 1, 0)
    }
}

/// 리포트·기록 탭의 처방 전환 표시 (RULES.md R13). 라벨은 사용자 메모 그대로이며 앱은 해석하지 않는다
struct PrescriptionMarker: Equatable {
    let startDate: Date
    let label: String?
    let isFirstInPeriod: Bool
}
