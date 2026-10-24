import ActivityKit
import Foundation

/// D6 투약일 Live Activity를 시작·갱신·종료한다. 서버 푸시 없음. 테스트·미리보기는 Fake
protocol LiveActivityControlling: AnyObject {
    /// `scheduled`가 있으면 그 예정으로 보이게, nil이면 있던 활동을 끝낸다
    func sync(scheduled: Date?, staleDate: Date?) async
}

final class LiveActivityService: LiveActivityControlling {
    func sync(scheduled: Date?, staleDate: Date?) async {
        let current = Activity<DoseDayAttributes>.activities
        guard let scheduled else {
            for activity in current {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        let content = ActivityContent(state: DoseDayAttributes.ContentState(scheduledDate: scheduled), staleDate: staleDate)
        if let activity = current.first {
            if activity.content.state != content.state || activity.content.staleDate != content.staleDate {
                await activity.update(content)
            }
            // 둘 이상이면 하나만 남긴다
            for extra in current.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        // 사용자가 설정에서 끈 경우 시작하지 않는다
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(attributes: DoseDayAttributes(), content: content, pushType: nil)
    }
}

final class FakeLiveActivityService: LiveActivityControlling {
    private(set) var scheduled: Date?
    private(set) var syncCount = 0

    func sync(scheduled: Date?, staleDate: Date?) async {
        self.scheduled = scheduled
        syncCount += 1
    }
}
