import SwiftUI

// DESIGN_SYSTEM.md 3. 타이포그래피. 시스템 폰트, Dynamic Type 대응. 숫자는 `.monospacedDigit()`.
enum Typography {
    /// 카운트다운 "D-3", "D-Day", "D+1". 56pt bold rounded. 앱에서는 `@ScaledMetric`으로 크기를 키운다.
    static let display = Font.system(size: 56, weight: .bold, design: .rounded).monospacedDigit()
    /// 셀 핵심 수치 "78.4", "18시간 42분"
    static let metricLarge = Font.system(size: 28, weight: .semibold).monospacedDigit()
    /// 화면·시트 제목
    static let title = Font.title2.weight(.semibold)
    /// 카드 좌측 상단 섹션 제목
    static let sectionHeader = Font.headline.weight(.semibold)
    /// 본문
    static let body = Font.body.monospacedDigit()
    /// 버튼, 칩, `metricLarge` 옆 단위
    static let label = Font.subheadline.weight(.medium)
    /// 날짜, 출처, 작은 수치 옆 단위, 셀 라벨. 색은 `inkSecondary`
    static let caption = Font.caption.monospacedDigit()
    /// 회차 코드, 리포트 마디 칸
    static let mono = Font.body.monospaced()

    /// 본문 줄 간격 여유
    static let bodyLineSpacing: CGFloat = 4
}
