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

    /// 패키지 하나 = 4회 = 약 한 달 (주 1회). 1회용 펜이면 펜 4개, 여러 회 쓰는 펜이면 펜 1개 (2026-10-24 사람 설명)
    static let dosesPerPackage = 4

    /// 1회용 펜(펜당 회차 1)의 회차 위치: n번째 패키지의 k번째 펜. `penPosition`과 같은 셈을 패키지 단위로
    static func packagePosition(sequence: Int) -> (package: Int, pen: Int) {
        let position = penPosition(sequence: sequence, dosesPerPen: dosesPerPackage)
        return (package: position.pen, pen: position.position)
    }

    /// R13-1. 펜마다 쓴 회차 수. 쓴 회차(취소 제외)를 앞 펜부터 차례로 채운다. 사실만 보이고 판단하지 않는다
    static func penStatus(p: PrescriptionSnapshot, doses: [DoseSnapshot]) -> PenStatus {
        let perPen = max(p.dosesPerPen, 1)
        let penCount = max(p.totalDoses / perPen, 0)
        let used = min(usedDoses(doses), penCount * perPen)
        let pens = (0..<penCount).map { index in min(max(used - index * perPen, 0), perPen) }
        return PenStatus(usedPerPen: pens, dosesPerPen: perPen)
    }

    // MARK: 처방 구간 색 (D7, R13-2)

    /// 처방 구간 색 개수. 처방 시작 순서대로 돌려 쓴다
    static let colorSlotCount = 4

    /// 처방마다 색 자리(0..<4). 시작일 순서(같으면 입력 순서)대로 0, 1, 2, 3, 0 …
    /// 처방을 구분할 뿐 용량·단계와 무관하고 순서·강도 의미가 없다 (COMPLIANCE.md 2.1-1, 2.2). 입력 순서대로 돌려준다
    static func colorSlots(startDates: [Date]) -> [Int] {
        let order = startDates.indices.sorted { (startDates[$0], $0) < (startDates[$1], $1) }
        var slots = Array(repeating: 0, count: startDates.count)
        for (rank, index) in order.enumerated() {
            slots[index] = rank % colorSlotCount
        }
        return slots
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

    /// 펜 하나에 한 번씩 쓰는 1회용 펜
    var isSingleUse: Bool { dosesPerPen == 1 }

    /// 그림의 패키지 묶음. 1회용 펜은 4개씩, 여러 회 쓰는 펜은 1개씩 (마지막 묶음은 모자랄 수 있다)
    var packages: [[Int]] {
        let size = isSingleUse ? PrescriptionRules.dosesPerPackage : 1
        return stride(from: 0, to: usedPerPen.count, by: size).map { start in
            Array(usedPerPen[start..<min(start + size, usedPerPen.count)])
        }
    }
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
