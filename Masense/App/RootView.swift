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
    @State private var showsSplash = RootView.startsWithSplash
    /// 마선생 한마디 팝업 (D18). 세 탭이 함께 쓴다 (같은 한 줄을 하루 두 번 띄우지 않게)
    @State private var coach = CoachPopupCenter()

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
        .overlay {
            if showsSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.coach, coach)
        // 시작 전환 화면이 덮고 있는 동안에는 팝업을 띄우지 않는다 (걷힌 뒤 닿아 있는 자리에서 뜬다)
        .onChange(of: showsSplash, initial: true) { _, shows in coach.isPaused = shows }
        .task {
            // 시작 전환 화면: 1초 머문 뒤 흐려지며 사라진다. 그동안 아래에서 온보딩·홈을 준비한다
            guard showsSplash else { return }
            #if DEBUG
            if ScreenshotRoute.current == .splash { return }
            #endif
            try? await Task.sleep(for: SplashView.duration)
            withAnimation(.easeOut(duration: 0.3)) { showsSplash = false }
        }
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
            Task { await services.refreshReminders(context: context) }
        }
    }
}

extension RootView {
    /// 앱을 새로 열 때만. 백그라운드에서 돌아올 때는 보이지 않는다 (상태가 살아 있으므로).
    /// 스크린샷 경로(DEBUG `-route`)로 띄울 때는 바로 화면으로 간다
    static var startsWithSplash: Bool {
        #if DEBUG
        return ScreenshotRoute.current == nil || ScreenshotRoute.current == .splash
        #else
        return true
        #endif
    }
}

/// 탭 3개 + 설정 push (SCREENS.md 내비게이션 구조)
struct MainTabView: View {
    private enum Tab: Hashable {
        case today, history, clinic, report
    }

    @State private var selection: Tab = MainTabView.initialTab
    @Environment(\.router) private var router

    private static var initialTab: Tab {
        #if DEBUG
        switch ScreenshotRoute.current {
        case .historyDose?, .historyCondition?, .historyWeight?, .historyHabits?: return .history
        case .report?: return .report
        case .clinic?, .clinicVisit?: return .clinic
        default: break
        }
        #endif
        return .today
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                // 1-5 진료 카드 "리포트 준비" → 리포트 탭
                TodayView(openReport: { selection = .report })
                    .coachPopupOverlay()
            }
            .tabItem { Label("tab.today", systemImage: "house") }
            .tag(Tab.today)

            NavigationStack {
                HistoryView()
                    .coachPopupOverlay(appearSpot: .history)
            }
            .tabItem { Label("tab.history", systemImage: "calendar") }
            .tag(Tab.history)

            NavigationStack {
                // D20 진료 탭: 진료 전 물어볼 것, 진료 직후 기록·검사 결과
                ClinicView(openReport: { selection = .report })
                    .coachPopupOverlay(appearSpot: .clinic)
            }
            .tabItem { Label("tab.clinic", systemImage: "list.clipboard") }
            .tag(Tab.clinic)

            NavigationStack {
                ReportView()
                    .coachPopupOverlay(appearSpot: .report)
            }
            .tabItem { Label("tab.report", systemImage: "doc.text") }
            .tag(Tab.report)
        }
        .tint(Color.accent)
        // 알림·위젯에서 들어오면 오늘 탭으로. 시트는 오늘 화면이 연다
        .onChange(of: router.pending, initial: true) { _, route in
            if route != nil {
                selection = .today
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(ModelContainer.preview)
}
