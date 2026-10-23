import Foundation

#if DEBUG
/// 육안 확인·스토어 스크린샷용 시작 화면. 실행 인자 `-route <값>` (DEBUG 빌드 전용).
/// CI `screenshots.yml`이 `-seedSampleData`와 함께 화면마다 앱을 다시 띄워 찍는다.
enum ScreenshotRoute: String, CaseIterable {
    /// 시작 전환 화면에 머문다
    case splash
    case today
    case settings
    case historyDose = "history.dose"
    case historyCondition = "history.condition"
    case historyWeight = "history.weight"
    case historyHabits = "history.habits"
    case report
    case doseSheet = "sheet.dose"
    case conditionSheet = "sheet.condition"
    case proteinSheet = "sheet.protein"
    case strengthSheet = "sheet.strength"
    case backfillSheet = "sheet.backfill"
    case questionsSheet = "sheet.questions"
    case weightTrendSheet = "sheet.weightTrend"
    case importSheet = "sheet.import"
    case importResult = "sheet.import.result"

    static let current: ScreenshotRoute? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-route"), arguments.indices.contains(index + 1) else { return nil }
        return ScreenshotRoute(rawValue: arguments[index + 1])
    }()
}
#endif
