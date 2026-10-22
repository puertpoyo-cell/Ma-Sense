import Foundation

enum PaceNotice: Equatable {
    /// `pace.notice`: 일반 권장 속도(주 0.5~1 kg)보다 빠르게 줄었다는 사실 + "의사와 상의하세요"
    case fasterThanGeneralGuide
}

/// R8 감량 속도 안내. 빠른 경우에만 안내하고, 느리거나 늘어난 경우에는 아무것도 하지 않는다.
enum PaceRules {
    /// 주당 변화 기준 (kg). 이보다 더 줄면(더 빠르게 감소) 해당.
    /// 일반 권장 속도 주 0.5~1 kg(CDC, 주 1~2파운드)의 상한. 2026-10-22 주 1% 기준에서 바꿈
    static let weeklyChangeThresholdKg = -1.0

    /// 최근 3주 주 평균으로 만든 2개 주간 변화가 모두 기준을 넘을 때. 빈 주가 끼면 계산하지 않는다
    static func paceNotice(series: [WeekPoint]) -> PaceNotice? {
        guard series.count >= 3 else { return nil }
        let recent = series.suffix(3).map(\.averageKg)
        guard let first = recent[0], let second = recent[1], let third = recent[2] else {
            return nil
        }
        let threshold = weeklyChangeThresholdKg
        return second - first < threshold && third - second < threshold ? .fasterThanGeneralGuide : nil
    }
}
