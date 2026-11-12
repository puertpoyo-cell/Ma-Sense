import AppIntents
import SwiftData

/// D51 Siri·단축어 "투약 기록". 지금 시각으로 이번 마디를 기록한다 (부위 기록 없음, 앱에서 고친다).
/// 문구에 약 이름·용량 없음 (COMPLIANCE.md)
struct LogDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.logDose.title"
    static let description = IntentDescription("intent.logDose.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try AppRuntime.sharedContainer()
        let now = Date()
        let outcome = QuickLogService.log(in: container.mainContext, at: now, calendar: .current)
        if case .log = outcome {
            await AppRuntime.services?.refreshReminders(context: container.mainContext, now: now)
        }
        return .result(dialog: IntentDialog(stringLiteral: QuickLogService.message(for: outcome)))
    }
}

/// D51 Siri·단축어 "다음 투약 언제". 날짜와 시각만 읽어 준다
struct NextDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.nextDose.title"
    static let description = IntentDescription("intent.nextDose.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try AppRuntime.sharedContainer()
        let now = Date()
        let snapshot = WidgetService.snapshot(context: container.mainContext, now: now, calendar: .current)
        return .result(dialog: IntentDialog(stringLiteral: QuickLogService.nextDoseMessage(snapshot: snapshot, now: now, calendar: .current)))
    }
}

/// Siri에 바로 말할 수 있는 문구. 한국어 문구는 `Resources/AppShortcuts.xcstrings`
struct MasenseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogDoseIntent(),
            phrases: [
                "Log a dose in \(.applicationName)",
                "Record my dose with \(.applicationName)",
            ],
            shortTitle: "intent.logDose.title",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: NextDoseIntent(),
            phrases: [
                "When is my next dose in \(.applicationName)",
                "Next dose in \(.applicationName)",
            ],
            shortTitle: "intent.nextDose.title",
            systemImageName: "calendar"
        )
    }
}
