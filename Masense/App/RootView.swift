import SwiftData
import SwiftUI

/// 탭 3개 + 설정 push (SCREENS.md 내비게이션 구조). 앱은 다크 고정.
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem { Label("tab.today", systemImage: "house") }

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("tab.history", systemImage: "calendar") }

            NavigationStack {
                ReportView()
            }
            .tabItem { Label("tab.report", systemImage: "doc.text") }
        }
        .tint(Color.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
        .modelContainer(ModelContainer.preview)
}
