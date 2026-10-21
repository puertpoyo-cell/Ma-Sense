import SwiftData
import SwiftUI

/// 첫 실행이면 온보딩(S0), 아니면 탭 3개. 앱은 다크 고정.
struct RootView: View {
    private enum Phase {
        case loading, onboarding, main
    }

    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                MidnightBackground()
            case .onboarding:
                OnboardingView { phase = .main }
            case .main:
                MainTabView()
                    .environment(\.restartOnboarding) { phase = .onboarding }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            guard phase == .loading else { return }
            // 온보딩 도중 종료했다가 다시 열어도 역할·연령 확인을 마쳤으면 홈으로 간다.
            // 처방이 없으면 홈 빈 상태에서 입력할 수 있다.
            let settings = try? UserSettings.current(in: context)
            phase = settings?.hasCompletedOnboarding == true ? .main : .onboarding
        }
        .onChange(of: scenePhase) { _, newPhase in
            // R4: 포그라운드로 올 때마다 전부 취소 후 재등록
            guard newPhase == .active, phase == .main else { return }
            Task { await services.refreshNotifications(context: context) }
        }
    }
}

/// 탭 3개 + 설정 push (SCREENS.md 내비게이션 구조)
struct MainTabView: View {
    private enum Tab: Hashable {
        case today, history, report
    }

    @State private var selection: Tab = .today

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                // 1-5 진료 카드 "리포트 준비" → 리포트 탭
                TodayView(openReport: { selection = .report })
            }
            .tabItem { Label("tab.today", systemImage: "house") }
            .tag(Tab.today)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("tab.history", systemImage: "calendar") }
            .tag(Tab.history)

            NavigationStack {
                ReportView()
            }
            .tabItem { Label("tab.report", systemImage: "doc.text") }
            .tag(Tab.report)
        }
        .tint(Color.accent)
    }
}

#Preview {
    RootView()
        .modelContainer(ModelContainer.preview)
}
