import Foundation

/// 출시 전에 사람이 정하는 값들. 정해지기 전에는 관련 UI를 숨긴다.
enum AppConfig {
    /// 개인정보 처리방침 URL (COMPLIANCE.md 5). 원문 docs/privacy/index.html을 Vercel에 게시 (2026-10-22, 시행 2026-10-30)
    /// nil이면 설정 > 정보에 항목을 보이지 않는다
    static let privacyPolicyURL: URL? = URL(string: "https://masense-privacy.vercel.app/")

    /// 단백질 권고 범위(1.2~1.6 g/kg) 출처 문구의 `Localizable` 키 (COMPLIANCE.md 2.2: 출처 명시가 허용 조건).
    /// nil이면 설정의 권고 범위 안내를 보이지 않는다. 목표 입력과 기록은 출처와 무관하게 동작한다.
    /// 2026-10-22 결정: 표시. 출처는 2025 미국 4개 학회 공동 권고문 (감량 중 1.2~1.6 g/kg/일, 지속 2 g/kg/일 초과는 피함)
    static let proteinGuideSource: String? = "protein.source"

    /// 감량 속도 일반 권장 범위(주 0.5~1 kg) 출처 문구의 `Localizable` 키 (COMPLIANCE.md 2.2).
    /// nil이면 체중 카드의 감량 속도 안내(R8)를 보이지 않는다. 2026-10-22 결정: CDC 기준으로 표시
    static let paceGuideSource: String? = "pace.source"

    // MARK: 번들 정보

    /// "1.0.0". 리포트 바닥글
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// "5" (CURRENT_PROJECT_VERSION). 설정 > 정보, TestFlight 피드백에서 빌드를 가리킬 때
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    /// "0.2 (5)". 설정 > 정보 (D22, 2026-10-28 사람 요청 "빌드 번호 텍스트")
    static var appVersionWithBuild: String {
        "\(appVersion) (\(buildNumber))"
    }

    /// 오픈 베타 동안 설정 > 정보에 안내 한 줄 (D22). 정식 출시 때 false로
    static let isOpenBeta = true

    /// N-I1 (v2 준비): 개인 iCloud 동기화. **사람이 Xcode에서 iCloud(CloudKit) Capability와 컨테이너
    /// `iCloud.com.puertpoyo.masense`, Background Modes(Remote notifications)를 켠 뒤에만** true로 바꾼다 (TESTFLIGHT.md 7).
    /// Capability 없이 true면 앱이 시작할 때 컨테이너를 못 열어 죽는다. 켤 때 처리방침 2장·3장을 "iCloud에 백업됩니다"로 고친다
    static let iCloudSyncEnabled = false
}
