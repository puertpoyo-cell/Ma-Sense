import SwiftUI
import WidgetKit

/// 위젯 확장 (D6). 홈·잠금화면 "다음 투약" 위젯과 투약일 Live Activity. 앱이 App Group에 써 둔 요약만 읽고 SwiftData는 열지 않는다
@main
struct MasenseWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextDoseWidget()
        DoseDayLiveActivity()
    }
}
