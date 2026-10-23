import ActivityKit
import Foundation

/// 투약일 Live Activity (D6, SCREENS.md Live Activity). 서버 푸시 없이 앱이 시작·갱신·종료한다.
/// 투약일에 앱을 열면 시작하고, 투약을 기록하거나 그날이 지나면 끝난다. 이 파일은 앱과 위젯 확장 두 타깃에 들어간다
struct DoseDayAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 오늘 마디의 예정 일시
        var scheduledDate: Date
    }
}
