import Foundation

/// 접히는 기기에서 펼칠 때의 배치 (D21, 2026-10-27 사람 요청). 수치는 Sift와 같은 박자
/// (접힌 폭 유지 1초 → 0.8초 한 번에 넓은 배치).
/// 화면 회전은 폭과 높이가 맞바뀌므로 "펼침"으로 보지 않는다
enum UnfoldRules {
    /// 펼친 뒤 접힌 배치를 그대로 두는 시간 (앱이 앞에 있을 때부터)
    static let holdSeconds: Double = 1
    /// 넓은 배치로 바뀌는 애니메이션 길이
    static let unfoldSeconds: Double = 0.8
    /// 폭이 이 비율 이상 늘면 펼침
    static let minWidthGrowth: CGFloat = 1.3
    /// 높이가 이 비율보다 많이 바뀌면 회전으로 본다
    static let maxHeightChange: CGFloat = 0.2
    /// 가로로 펼쳤을 때 2단이 되는 최소 폭
    static let twoColumnMinWidth: CGFloat = 640

    /// 폭이 접힌 폭에서 펼친 폭으로 늘었는지. 회전(높이도 크게 바뀜)·줄어듦은 아니다
    static func isUnfold(from old: CGSize, to new: CGSize) -> Bool {
        guard old.width > 0, old.height > 0 else { return false }
        let widthGrew = new.width >= old.width * minWidthGrowth
        let heightKept = abs(new.height - old.height) <= old.height * maxHeightChange
        return widthGrew && heightKept
    }

    /// 탭 화면(오늘·기록·진료·리포트) 단 수. 가로(폭 > 높이)이고 충분히 넓을 때만 2단, 세로 펼침은 1단 (D21·D23)
    static func columns(for size: CGSize) -> Int {
        size.width > size.height && size.width >= twoColumnMinWidth ? 2 : 1
    }

    // MARK: 접힌 화면의 옆 레일 (D23-1, 2026-10-30 사람 요청 "접힌 UI에서도 상·하단 고정 버튼은 좌/우로")

    /// 상태 표시줄이 옆 기둥에 있다고 보는 최소 옆 여백
    static let sideStatusBarMinInset: CGFloat = 32
    /// 반대쪽 옆 여백이 이보다 작아야 한쪽 기둥(접힌 화면)이다. 양쪽이 비슷하게 크면 보통 폰의 가로 회전
    static let sideStatusBarMaxOppositeInset: CGFloat = 16
    /// 위 여백이 이보다 작아야 상태 표시줄이 위가 아니라 옆에 있다
    static let sideStatusBarMaxTopInset: CGFloat = 24

    /// 탭 레일을 놓을 쪽. 상태 표시줄 기둥의 반대쪽 (예: 기둥이 오른쪽이면 왼쪽 레일).
    /// nil이면 보통 배치(아래 탭 바). 안전 영역 값만 보고 판단하므로 기기 종류·방향을 묻지 않는다
    static func tabRailEdge(safeAreaTop top: CGFloat, leading: CGFloat, trailing: CGFloat) -> HorizontalEdge? {
        guard top < sideStatusBarMaxTopInset else { return nil }
        if trailing >= sideStatusBarMinInset, leading < sideStatusBarMaxOppositeInset { return .leading }
        if leading >= sideStatusBarMinInset, trailing < sideStatusBarMaxOppositeInset { return .trailing }
        return nil
    }

    enum HorizontalEdge: Equatable {
        case leading, trailing
    }
}
