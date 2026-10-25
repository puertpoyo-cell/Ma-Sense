import Foundation

/// 바디맵 그림 (D13). 체형 단계가 아니라 여/남 두 가지 평균 체형만 (COMPLIANCE.md 2.2)
enum BodyFigure: String, CaseIterable, Hashable {
    case male, female
}

/// 설정의 바디맵 그림 선택. 기본은 건강 앱을 따른다
enum BodyFigurePreference: String, CaseIterable, Hashable {
    case automatic, male, female
}

enum BodyFigureRules {
    /// 건강 앱에 성별이 없을 때 (2026-10-25 사람 결정)
    static let fallback: BodyFigure = .male

    /// 직접 고른 그림이 먼저, "건강 앱 따라"면 건강 앱의 성별, 그것도 없으면 남성
    static func figure(preference: BodyFigurePreference, healthFigure: BodyFigure?) -> BodyFigure {
        switch preference {
        case .male: return .male
        case .female: return .female
        case .automatic: return healthFigure ?? fallback
        }
    }
}
