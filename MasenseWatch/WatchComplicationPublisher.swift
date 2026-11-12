import Foundation
import WidgetKit

/// D51 시계 화면 컴플리케이션에 보일 요약을 워치의 App Group에 쓴다 (iPhone 위젯과 같은 `WidgetSnapshot`, 같은 규칙).
/// 워치 앱이 열려 있을 때 기록이 바뀌면 다시 쓴다. 내용이 같으면 다시 그리지 않는다
enum WatchComplicationPublisher {
    private static var lastPublished: WidgetSnapshot?

    static func publish(prescription: PrescriptionSnapshot?, doses: [DoseSnapshot], allDoses: [DoseSnapshot], now: Date, calendar: Calendar) {
        let snapshot = WidgetRules.snapshot(prescription: prescription, doses: doses, allDoses: allDoses, now: now, calendar: calendar)
        var comparable = snapshot
        comparable.updatedAt = .distantPast
        guard comparable != lastPublished else { return }
        guard (try? snapshot.write()) != nil else { return }
        lastPublished = comparable
        WidgetCenter.shared.reloadAllTimelines()
    }
}
