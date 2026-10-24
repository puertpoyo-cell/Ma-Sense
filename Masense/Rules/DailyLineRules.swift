import Foundation

/// 오늘 화면 맨 위 사실 한 줄 (R17, D8). 칭찬·응원·평가 없이 지금 상태 하나만
enum DailyLine: Equatable {
    /// 오늘이 예정일이고 이번 마디 기록 전. 직전 투약 부위(모르면 nil)
    case doseDay(lastSite: BodySite?)
    /// 남은 회차가 `lowThreshold` 이하. 1회용 펜이면 펜 수로 말한다
    case lowSupply(remaining: Int, isSingleUsePen: Bool)
    /// 최근 7일 체중 기록 없음
    case noRecentWeight

    /// 하루에 한 번 닫는 데 쓰는 키
    var kind: String {
        switch self {
        case .doseDay: return "doseDay"
        case .lowSupply: return "lowSupply"
        case .noRecentWeight: return "noRecentWeight"
        }
    }
}

enum DailyLineRules {
    static let lowThreshold = 1
    static let weightGapDays = 7

    /// 우선순위: 투약일 > 남은 회차 > 체중 기록 없음. 해당이 없으면 nil
    static func line(
        prescription: PrescriptionSnapshot?,
        doses: [DoseSnapshot],
        allDoses: [DoseSnapshot],
        weights: [WeightSampleSnapshot],
        now: Date,
        calendar: Calendar
    ) -> DailyLine? {
        if let p = prescription {
            let cycles = CycleRules.cycles(for: p, doses: doses, now: now, until: .distantFuture, calendar: calendar)
            switch CycleRules.nextDose(cycles: cycles, doses: doses, now: now) {
            case let .due(cycle, _)?, let .overdue(cycle, _)?:
                if calendar.isDate(cycle.scheduledDate, inSameDayAs: now) {
                    let last = allDoses.filter { !$0.isCancelled }.max { $0.administeredAt < $1.administeredAt }
                    return .doseDay(lastSite: last?.site)
                }
            default:
                break
            }
            let remaining = PrescriptionRules.remainingDoses(p: p, doses: doses)
            if remaining > 0, remaining <= lowThreshold {
                return .lowSupply(remaining: remaining, isSingleUsePen: p.dosesPerPen == 1)
            }
        }
        guard let since = calendar.date(byAdding: .day, value: -weightGapDays, to: now) else { return nil }
        if !weights.contains(where: { $0.measuredAt > since && $0.measuredAt <= now }) {
            return .noRecentWeight
        }
        return nil
    }
}
