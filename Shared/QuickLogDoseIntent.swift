import AppIntents
import WidgetKit

/// D51 위젯의 "투약 기록" 버튼. 누른 시각을 App Group에 남기고 위젯 요약을 "기록 완료"로 바꾼다.
/// `LiveActivityIntent`라 시스템이 앱 프로세스에서 돌리면 `QuickLogBridge.drain`이 바로 저장소에 넣고 알림을 다시 맞춘다.
/// 위젯 프로세스에서 돌면 남겨 둔 시각을 앱이 다음에 깨어날 때 넣는다. 약 이름·용량 없음 (COMPLIANCE.md)
struct QuickLogDoseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.logDose.title"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        let now = Date()
        QuickLogQueue.append(now)
        if let snapshot = WidgetSnapshot.read() {
            try? snapshot.afterQuickLog(at: now, calendar: .current).write()
        }
        if let drain = QuickLogBridge.drain {
            await drain()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 앱이 시작할 때 채운다. 위젯 확장에서는 비어 있다
enum QuickLogBridge {
    static var drain: (() async -> Void)?
}
