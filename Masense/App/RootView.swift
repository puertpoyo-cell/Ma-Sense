import Combine
import CoreData
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
            // D26: iCloud로 받은 설정과 이 기기 설정이 겹쳐 있으면 먼저 하나로 (온보딩을 마친 쪽이 남는다)
            try? SyncMergeService.mergeDuplicates(context: context)
            let settings = try? UserSettings.current(in: context)
            phase = settings?.hasCompletedOnboarding == true ? .main : .onboarding
        }
        .onChange(of: scenePhase) { _, newPhase in
            // R4: 포그라운드로 올 때마다 전부 취소 후 재등록
            guard newPhase == .active, phase == .main else { return }
            try? SyncMergeService.mergeDuplicates(context: context)
            Task { await services.refreshReminders(context: context) }
        }
        // D26: 다른 기기의 기록이 iCloud로 들어오면 중복을 정리하고 알림·위젯을 다시 맞춘다.
        // 한꺼번에 여러 번 오므로 2초 모아서 한 번
        .onReceive(
            NotificationCenter.default
                .publisher(for: .NSPersistentStoreRemoteChange)
                .debounce(for: .seconds(2), scheduler: RunLoop.main)
        ) { _ in
            remoteChangesArrived()
        }
    }
}

extension RootView {
    /// D26 iCloud로 다른 기기 기록이 들어왔을 때
    private func remoteChangesArrived() {
        guard AppConfig.cloudSyncActive else { return }
        try? SyncMergeService.mergeDuplicates(context: context)
        // 새 기기에서 온보딩 중인데 다른 기기의 설정(온보딩 마침)이 들어오면 바로 홈으로
        if phase == .onboarding, (try? UserSettings.current(in: context))?.hasCompletedOnboarding == true {
            phase = .main
        }
        guard phase == .main else { return }
        Task { await services.refreshReminders(context: context) }
    }

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

/// D31 (2026-11-01 사람 결정 "탭 3개로: 오늘 / 기록(진료·의사와 볼 리포트 통합) / 설정"). 아이콘도 뜻이 바로 보이게
struct MainTabView: View {
    private enum Tab: Hashable {
        case today, records, settings
    }

    @State private var selection: Tab = MainTabView.initialTab.tab
    @State private var recordsSegment: RecordsSegment = MainTabView.initialTab.segment
    @Environment(\.router) private var router

    private static var initialTab: (tab: Tab, segment: RecordsSegment) {
        #if DEBUG
        switch ScreenshotRoute.current {
        case .history?, .historyDose?, .historyCondition?, .historyWeight?, .historyHabits?: return (.records, .days)
        case .report?: return (.records, .report)
        case .clinic?, .clinicVisit?: return (.records, .clinic)
        default: break
        }
        #endif
        return (.today, .days)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                // 1-5 진료 카드 "리포트 준비" → 기록 탭의 리포트
                TodayView(
                    openReport: { open(.report) },
                    openClinic: { open(.clinic) }
                )
                .coachPopupOverlay()
            }
            .tabItem { Label("tab.today", systemImage: "sun.max") }
            .tag(Tab.today)

            // 날짜별 기록 · 진료 · 리포트(의사와 볼 내보내기)를 한 탭에서 위쪽 전환으로
            RecordsTab(segment: $recordsSegment)
                .tabItem { Label("tab.records", systemImage: "book.closed") }
                .tag(Tab.records)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("settings.title", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(Color.accent)
        // 알림·위젯에서 들어오면 오늘 탭으로. 시트는 오늘 화면이 연다
        .onChange(of: router.pending, initial: true) { _, route in
            if route != nil {
                selection = .today
            }
        }
    }

    private func open(_ segment: RecordsSegment) {
        recordsSegment = segment
        selection = .records
    }
}

/// D31 기록 탭 안의 세 갈래
enum RecordsSegment: String, CaseIterable, Hashable {
    /// 날짜별 기록 (D20 날짜 중심)
    case days
    /// 진료 (예약·처방·결과·받은 펜)
    case clinic
    /// 의사와 볼 리포트·내보내기
    case report

    var titleKey: LocalizedStringKey { LocalizedStringKey("records.segment." + rawValue) }
}

/// D31 기록 탭. 위쪽 전환으로 날짜별 기록 · 진료 · 리포트
struct RecordsTab: View {
    @Binding var segment: RecordsSegment

    var body: some View {
        Group {
            switch segment {
            case .days:
                // 모아 보기 이동을 위해 자기 NavigationStack(path)을 가진다
                HistoryView()
                    .coachPopupOverlay(appearSpot: .history)
            case .clinic:
                NavigationStack {
                    ClinicView(openReport: { segment = .report })
                        .coachPopupOverlay(appearSpot: .clinic)
                }
            case .report:
                NavigationStack {
                    ReportView()
                        .coachPopupOverlay(appearSpot: .report)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("records.segment.picker", selection: $segment) {
                ForEach(RecordsSegment.allCases, id: \.self) { item in
                    Text(item.titleKey).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s2)
            .background(Color.midnight.opacity(0.92))
        }
    }
}

#Preview {
    RootView()
        .modelContainer(ModelContainer.preview)
}
