import Foundation

enum PaceNotice: Equatable {
    /// "최근 체중 변화가 일반 권고 범위(주 0.5~1%)보다 빠릅니다. 진료 때 상의해 보세요."
    case fasterThanGeneralGuide
}

/// R8 감량 속도 안내. 빠른 경우에만 안내하고, 느리거나 늘어난 경우에는 아무것도 하지 않는다.
enum PaceRules {
    /// 주당 변화율 기준 (%). 이보다 더 낮으면(더 빠르게 감소) 해당
    static let weeklyChangeThresholdPercent = -1.0

    /// 최근 3주 주 평균으로 만든 2개 주간 변화율이 모두 기준을 넘을 때. 빈 주가 끼면 계산하지 않는다
    static func paceNotice(series: [WeekPoint]) -> PaceNotice? {
        guard series.count >= 3 else { return nil }
        let recent = series.suffix(3).map(\.averageKg)
        guard let first = recent[0], let second = recent[1], let third = recent[2], first > 0, second > 0 else {
            return nil
        }
        // 곱한 뒤 나눠서 -1.0%가 정확히 -1.0으로 나오게 한다 (경계 테스트)
        let firstChange = (second - first) * 100 / first
        let secondChange = (third - second) * 100 / second
        let threshold = weeklyChangeThresholdPercent
        return firstChange < threshold && secondChange < threshold ? .fasterThanGeneralGuide : nil
    }
}
