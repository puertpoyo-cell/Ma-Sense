import Foundation

/// 출시 전에 사람이 정하는 값들. 정해지기 전에는 관련 UI를 숨긴다.
enum AppConfig {
    /// 개인정보 처리방침 URL (COMPLIANCE.md 5). 초안: docs/PRIVACY.md, docs/privacy/index.html
    /// 게시 위치가 정해지면 입력한다. nil이면 설정 > 정보에 항목을 보이지 않는다
    static let privacyPolicyURL: URL? = nil

    /// 단백질 권고 범위(1.2~1.6 g/kg) 출처 문구의 `Localizable` 키 (COMPLIANCE.md 2.2: 출처 명시가 허용 조건).
    /// nil이면 설정의 권고 범위 안내를 보이지 않는다. 목표 입력과 기록은 출처와 무관하게 동작한다.
    /// 2026-10-22 결정: 표시. 출처는 2025 미국 4개 학회 공동 권고문 (감량 중 1.2~1.6 g/kg/일, 지속 2 g/kg/일 초과는 피함)
    static let proteinGuideSource: String? = "protein.source"

    /// 감량 속도 일반 권장 범위(주 0.5~1 kg) 출처 문구의 `Localizable` 키 (COMPLIANCE.md 2.2).
    /// nil이면 체중 카드의 감량 속도 안내(R8)를 보이지 않는다. 2026-10-22 결정: CDC 기준으로 표시
    static let paceGuideSource: String? = "pace.source"
}
