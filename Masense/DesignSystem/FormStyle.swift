import SwiftUI

/// 리스트·폼 화면(기록 탭, 설정, 입력 시트)의 도면 스타일 (DESIGN_SYSTEM.md 5.1).
/// 카드 대신 `frost` 행과 `gridHairline` 구분선을 쓰고, 섹션 헤더는 `label` + `inkSecondary`.
extension View {
    /// 배경 `frost`, 행 구분선 `gridHairline`. `Section`이나 `Group`에 붙이면 그 안의 행 전부에 적용된다
    func frostRow() -> some View {
        listRowBackground(Color.frost)
            .listRowSeparatorTint(Color.gridHairline)
    }
}

/// 섹션 헤더: `label` + `inkSecondary`, 대문자 변환 없음
struct SectionHeaderText: View {
    private let text: Text

    init(_ key: LocalizedStringKey) {
        text = Text(key)
    }

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        text
            .font(Typography.label)
            .foregroundStyle(Color.inkSecondary)
            .textCase(nil)
    }
}
