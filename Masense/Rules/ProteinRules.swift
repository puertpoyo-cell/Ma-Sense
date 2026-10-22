import Foundation

/// R9 단백질 하루 상태. 목표 달성은 "채웠습니다" 한 줄, 미달은 "n g 기록"만. 경고·색 변화 없음
enum ProteinDayStatus: Equatable {
    case noTarget(estimated: Int)
    case below(estimated: Int, target: Int)
    case met(estimated: Int, target: Int)
}

/// R9 단백질 목표 안내, R10 식욕 저하일 모드.
enum ProteinRules {
    /// 일반 권고 범위 1.2~1.6 g/kg. 안내 옆에 항상 "개인 상황은 의사와 상의" 고정 문구
    static let guideLow = 1.2
    static let guideHigh = 1.6

    /// R10 식욕 저하일 "작게 자주" 칩 4개 (셰이크, 요거트, 두유, 계란). 식품 종류만, 양·칼로리 없음
    static let smallFrequentFoods: [ProteinFood] = [.proteinShake, .greekYogurt, .beans, .egg]

    /// 체중 × 1.2~1.6, 정수 g로 반올림
    static func proteinGuideRange(weightKg: Double) -> ClosedRange<Int> {
        let low = Int((weightKg * guideLow).rounded())
        let high = Int((weightKg * guideHigh).rounded())
        return low...max(low, high)
    }

    /// 식품별 기본값 합산 ("대략")
    static func estimatedGrams(for foods: [ProteinFood]) -> Int {
        foods.reduce(0) { $0 + $1.defaultGrams }
    }

    static func entries(on day: Date, from entries: [ProteinEntrySnapshot], calendar: Calendar) -> [ProteinEntrySnapshot] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// 목표가 없으면 추정치만. 목표는 사용자·의료진이 입력한다
    static func proteinDayStatus(entries: [ProteinEntrySnapshot], target: Int?) -> ProteinDayStatus {
        let estimated = entries.reduce(0) { $0 + $1.estimatedGrams }
        guard let target, target > 0 else { return .noTarget(estimated: estimated) }
        return estimated >= target ? .met(estimated: estimated, target: target) : .below(estimated: estimated, target: target)
    }
}
