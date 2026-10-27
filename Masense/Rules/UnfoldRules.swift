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

    /// 오늘 화면 단 수. 가로(폭 > 높이)이고 충분히 넓을 때만 2단, 세로 펼침은 1단
    static func columns(for size: CGSize) -> Int {
        size.width > size.height && size.width >= twoColumnMinWidth ? 2 : 1
    }
}
