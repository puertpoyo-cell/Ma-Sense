import SwiftUI

// DESIGN_SYSTEM.md 2. 타이포그래피. 시스템 폰트, Dynamic Type 대응. 숫자는 `.monospacedDigit()`.
enum Typography {
    /// 카운트다운 "D-3". 56pt bold rounded. 사용하는 뷰에서 `@ScaledMetric`으로 크기를 키운다.
    static let display = Font.system(size: 56, weight: .bold, design: .rounded)
    /// 카드 제목
    static let title = Font.title2.weight(.semibold)
    /// 본문
    static let body = Font.body
    /// 칩, 버튼
    static let label = Font.subheadline.weight(.medium)
    /// 날짜, 보조. 색은 `inkSecondary`
    static let caption = Font.caption
    /// 회차 "3 / 12"
    static let mono = Font.body.monospaced()

    /// 본문 줄 간격 여유
    static let bodyLineSpacing: CGFloat = 4
}
