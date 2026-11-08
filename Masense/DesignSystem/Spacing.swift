import CoreGraphics

// DESIGN_SYSTEM.md 4. 간격·격자. 기본 단위 4pt.
enum Spacing {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32
    static let s7: CGFloat = 48
    /// D46 (U1 A1) 떠 있는 탭 바 높이만큼 스크롤 아래 여유
    static let tabBarClearance: CGFloat = 72
    /// D46 (U1 A2) 마선생 팝업이 떠 있는 동안 더하는 아래 여유
    static let coachPopupClearance: CGFloat = 200

    /// 화면 좌우 여백
    static let screenHorizontal = s5
    /// 카드 간 간격
    static let cardGap = s4
    /// 카드 내부 패딩
    static let cardPadding = s5
    /// 도면 셀 내부 패딩. 격자선과 콘텐츠 사이 최소 `s3` (DESIGN_SYSTEM.md 4)
    static let cellPadding = s4
}

enum Radius {
    static let card: CGFloat = 20
    static let chip: CGFloat = 10
    static let button: CGFloat = 14
}
