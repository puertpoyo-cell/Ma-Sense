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

    // MARK: 펜 현황 (D7)

    /// R13-1. 펜마다 쓴 회차 수. 쓴 회차(취소 제외)를 앞 펜부터 차례로 채운다. 사실만 보이고 판단하지 않는다
    static func penStatus(p: PrescriptionSnapshot, doses: [DoseSnapshot]) -> PenStatus {
        let perPen = max(p.dosesPerPen, 1)
        let penCount = max(p.totalDoses / perPen, 0)
        let used = min(usedDoses(doses), penCount * perPen)
        let pens = (0..<penCount).map { index in min(max(used - index * perPen, 0), perPen) }
        return PenStatus(usedPerPen: pens, dosesPerPen: perPen)
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

    // MARK: 활성 처방 하나로 맞추기 (EXPORT_FORMAT.md 가져오기 규칙 7)

    /// 활성 처방이 둘 이상이면 `startDate`가 가장 늦은 것만 활성으로 둔다. 나머지는 보관하고,
    /// `endDate`가 비어 있으면 다음 처방 시작 전날로 채운다 (자기 시작일보다 앞서지 않게, `Prescription.activate`와 같은 규칙).
    /// 입력 순서를 그대로 돌려준다. 활성 처방이 하나 이하면 바꾸지 않는다
    static func resolvingActive(_ spans: [PrescriptionSpan], calendar: Calendar) -> [PrescriptionSpan] {
        let active = spans.filter(\.isActive)
        guard active.count > 1, let kept = active.max(by: { $0.startDate < $1.startDate }) else { return spans }
        return spans.map { span in
            guard span.isActive, span.id != kept.id else { return span }
            var resolved = span
            resolved.isActive = false
            if resolved.endDate == nil {
                // 같은 날 시작한 처방도 "다음"으로 본다. 활성으로 남는 처방이 있으므로 항상 하나는 있다
                let nextStart = spans
                    .filter { $0.id != span.id && $0.startDate >= span.startDate }
                    .map(\.startDate)
                    .min() ?? kept.startDate
                let ownStart = calendar.startOfDay(for: span.startDate)
                let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: nextStart)) ?? ownStart
                resolved.endDate = max(dayBefore, ownStart)
            }
            return resolved
        }
    }
}

/// 펜 현황 (R13-1, D7). 펜 수·펜당 회차는 처방 입력 그대로. 용량 수치는 다루지 않는다
struct PenStatus: Equatable {
    /// 펜마다 쓴 회차 수 (0...dosesPerPen), 처방 순서대로
    let usedPerPen: [Int]
    let dosesPerPen: Int

    var penCount: Int { usedPerPen.count }
    /// 한 회차라도 남은 펜 (쓰는 중인 펜 포함)
    var remainingPens: Int { usedPerPen.filter { $0 < dosesPerPen }.count }
    var remainingDoses: Int { usedPerPen.reduce(0) { $0 + dosesPerPen - $1 } }
}

/// 처방 이력 체인에서 활성·종료일만 다루는 값 (규칙 7)
struct PrescriptionSpan: Equatable {
    let id: UUID
    let startDate: Date
    var endDate: Date?
    var isActive: Bool
}

/// 리포트·기록 탭의 처방 전환 표시 (RULES.md R13). 라벨은 사용자 메모 그대로이며 앱은 해석하지 않는다
struct PrescriptionMarker: Equatable {
    let startDate: Date
    let label: String?
    let isFirstInPeriod: Bool
}
