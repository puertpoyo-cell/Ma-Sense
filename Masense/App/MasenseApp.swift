import SwiftData
import SwiftUI

@main
struct MasenseApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer.masense()
        } catch {
            // 온디바이스 저장소를 열지 못하면 앱이 할 수 있는 일이 없다.
            fatalError("ModelContainer could not be created: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
