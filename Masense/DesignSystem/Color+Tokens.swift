import SwiftUI

// DESIGN_SYSTEM.md 2. 색·재질 토큰. 앱은 다크 고정이며, 빨강·초록은 쓰지 않는다.
extension Color {
    /// 앱 배경
    static let midnight = Color(hex: 0x0B1220)
    /// 시트 배경
    static let midnightElevated = Color(hex: 0x111B2E)
    /// 카드 채움. `FrostCard`가 `.ultraThinMaterial`과 함께 쓴다.
    static let frost = Color.white.opacity(0.08)
    /// 기본 1px 외곽선 (칩, GhostButton)
    static let frostBorder = Color.white.opacity(0.14)
    /// `FrostCard` 테두리 그라데이션 위쪽. 심각도 3 강조 테두리
    static let frostHighlightTop = Color.white.opacity(0.22)
    /// `FrostCard` 테두리 그라데이션 아래쪽
    static let frostHighlightBottom = Color.white.opacity(0.10)
    /// 카드 내부 1px 도면 분할선
    static let gridHairline = Color.white.opacity(0.08)
    /// 분할선 교차점 `+` 마커
    static let gridCrosshair = Color(hex: 0x5E6B82, opacity: 0.5)
    /// 본문 텍스트, 핵심 숫자
    static let ink = Color(hex: 0xF2F5FA)
    /// 보조 텍스트, 숫자 옆 단위·분모, 셀 라벨
    static let inkSecondary = Color(hex: 0x9AA7BD)
    /// 비활성, 차트 축·보조선, 빈 슬롯
    static let inkTertiary = Color(hex: 0x5E6B82)
    /// 버튼, 선택 상태, 직전 1회 투약 부위, 스파크라인 (기본 테마 `midnight`)
    static let accent = Color(hex: 0x7FB3FF)
    /// 선택 배경, 강도 1·2, "① 마지막" 칩
    static let accentSoft = Color.accent.opacity(0.18)
    /// 안내 문구. 경고가 아닌 따뜻한 중립
    static let notice = Color(hex: 0xE8D9A8)

    /// 테마 구매 시 `accent`만 교체한다.
    static let accentSand = Color(hex: 0xE8C9A0)
    static let accentSage = Color(hex: 0xA8D5BA)

    // MARK: 리포트 PDF (라이트 강제, DESIGN_SYSTEM.md 2 오른쪽 열)

    static let paperBackground = Color.white
    static let paperInk = Color(hex: 0x111827)
    static let paperInkSecondary = Color(hex: 0x4B5563)
    static let paperInkTertiary = Color(hex: 0x9CA3AF)
    static let paperHairline = Color(hex: 0xE2E8F0)
    static let paperBorder = Color(hex: 0xCBD5E1)
    /// 기본 테마의 리포트 강조색
    static let paperAccent = Color(hex: 0x2563EB)

    /// 처방 구간 색 (D7, R13-2). 처방 시작 순서대로 돌려 쓰고 순서·강도 의미가 없다. 빨강·초록 없음
    static let prescriptionPalette: [Color] = [
        Color(hex: 0x7FB3FF), // 파랑 (accent와 같음)
        Color(hex: 0xE9BE6C), // 호박
        Color(hex: 0xB9A3FF), // 보라
        Color(hex: 0xC3CEDD), // 은회색
    ]
    /// 리포트(흰 종이)용 같은 순서의 진한 색
    static let paperPrescriptionPalette: [Color] = [
        Color(hex: 0x2F6FD6),
        Color(hex: 0xA86B12),
        Color(hex: 0x6B4FC9),
        Color(hex: 0x56657D),
    ]

    static func prescription(slot: Int) -> Color {
        prescriptionPalette[((slot % prescriptionPalette.count) + prescriptionPalette.count) % prescriptionPalette.count]
    }

    static func paperPrescription(slot: Int) -> Color {
        paperPrescriptionPalette[((slot % paperPrescriptionPalette.count) + paperPrescriptionPalette.count) % paperPrescriptionPalette.count]
    }

    /// 바디맵 최근 사용 부위 농도. `rank` 0이 직전 1회(선명), 1~3은 은은하게 (DESIGN_SYSTEM.md 5.3)
    static func siteRecent(rank: Int) -> Color {
        let opacities: [Double] = [1.0, 0.45, 0.35, 0.25]
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
