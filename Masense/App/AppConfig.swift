import Foundation

/// 출시 전에 사람이 정하는 값들. 정해지기 전에는 관련 UI를 숨긴다.
enum AppConfig {
    /// 개인정보 처리방침 URL (COMPLIANCE.md 5). 초안: docs/PRIVACY.md, docs/privacy/index.html
    /// 게시 위치가 정해지면 입력한다. nil이면 설정 > 정보에 항목을 보이지 않는다
    static let privacyPolicyURL: URL? = nil
}
