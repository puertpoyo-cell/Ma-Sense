import SwiftUI
import WidgetKit

/// D51 워치 컴플리케이션 (시계 화면의 "다음 투약"). 워치 앱이 App Group에 써 둔 요약만 읽고 저장소는 열지 않는다
@main
struct MasenseWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchNextDoseWidget()
    }
}
