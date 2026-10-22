import SwiftData
import SwiftUI

@main
struct MasenseApp: App {
    private let container: ModelContainer
    private let services = AppServices.live()

    init() {
        do {
            container = try ModelContainer.masense()
        } catch {
            // 온디바이스 저장소를 열지 못하면 앱이 할 수 있는 일이 없다.
            fatalError("ModelContainer could not be created: \(error)")
        }
        #if DEBUG
        // 스토어 스크린샷용: Xcode 스킴 실행 인자에 -seedSampleData를 넣으면 빈 저장소에 예시 데이터를 채운다
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData"),
           (try? container.mainContext.fetchCount(FetchDescriptor<Prescription>())) == 0 {
            try? SampleData.seed(into: container.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.services, services)
        }
        .modelContainer(container)
    }
}
