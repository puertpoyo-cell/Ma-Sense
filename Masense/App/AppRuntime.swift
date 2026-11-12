import SwiftData

/// D51 화면 밖(Siri·단축어·위젯 버튼)에서 앱 프로세스로 들어왔을 때 쓰는 저장소·서비스.
/// 저장소는 앱 전체에 하나만 연다 (iCloud 동기화가 한 저장소에 두 번 붙지 않게). `MasenseApp`이 시작할 때 채운다
enum AppRuntime {
    static var container: ModelContainer?
    static var services: AppServices?

    static func sharedContainer() throws -> ModelContainer {
        if let container { return container }
        let made = try ModelContainer.masense()
        container = made
        return made
    }
}
