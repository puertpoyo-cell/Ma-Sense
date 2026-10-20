import SwiftUI

// DESIGN_SYSTEM.md 1. 색 토큰. 앱은 다크 고정이며, 빨강·초록은 쓰지 않는다.
extension Color {
    /// 앱 배경
    static let midnight = Color(hex: 0x0B1220)
    /// 시트 배경
    static let midnightElevated = Color(hex: 0x111B2E)
    /// 카드 채움. `FrostCard`가 `.ultraThinMaterial`과 함께 쓴다.
    static let frost = Color.white.opacity(0.08)
    /// 카드 1px 테두리
    static let frostBorder = Color.white.opacity(0.14)
    /// 본문 텍스트
    static let ink = Color(hex: 0xF2F5FA)
    /// 보조 텍스트
    static let inkSecondary = Color(hex: 0x9AA7BD)
    /// 비활성, 격자선
    static let inkTertiary = Color(hex: 0x5E6B82)
    /// 버튼, 선택 상태, 라인 차트 (기본 테마 `midnight`)
    static let accent = Color(hex: 0x7FB3FF)
    /// 선택 배경
    static let accentSoft = Color.accent.opacity(0.18)
    /// 안내 문구. 경고가 아닌 따뜻한 중립
    static let notice = Color(hex: 0xE8D9A8)

    /// 리포트 PDF(흰 배경)에서만 쓰는 본문색
    static let inkOnPaper = Color(hex: 0x111827)

    /// 테마 구매 시 `accent`만 교체한다.
    static let accentSand = Color(hex: 0xE8C9A0)
    static let accentSage = Color(hex: 0xA8D5BA)

    /// 바디맵 최근 사용 부위 농도. `rank` 0이 가장 최근.
    static func siteRecent(rank: Int) -> Color {
        let opacities: [Double] = [1.0, 0.7, 0.45, 0.25]
        let clamped = min(max(rank, 0), opacities.count - 1)
        return Color.accent.opacity(opacities[clamped])
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
