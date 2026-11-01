import EventKit
import EventKitUI
import SwiftUI

/// D28 캘린더 앱에 진료 일정 넣기. 시스템 일정 편집 화면을 띄워 사람이 확인하고 "추가"를 누른다.
/// iOS 17부터 이 화면은 캘린더 권한 없이 쓸 수 있어 권한을 묻지 않는다 (앱이 캘린더를 읽지 않음)
/// 제목은 "진료"만. 약 이름은 넣지 않는다 (COMPLIANCE.md)
struct CalendarEventSheet: UIViewControllerRepresentable {
    let date: Date
    let title: String
    var onDone: () -> Void = {}

    private static let store = EKEventStore()

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let event = EKEvent(eventStore: Self.store)
        event.title = title
        let calendar = Calendar.current
        if ClinicRules.hasTime(date, calendar: calendar) {
            event.startDate = date
            event.endDate = date.addingTimeInterval(3_600)
            // 하루 전·2시간 전 알림
            event.alarms = [EKAlarm(relativeOffset: -86_400), EKAlarm(relativeOffset: -7_200)]
        } else {
            event.isAllDay = true
            event.startDate = calendar.startOfDay(for: date)
            event.endDate = event.startDate
            event.alarms = [EKAlarm(relativeOffset: -15 * 3_600)]
        }
        let controller = EKEventEditViewController()
        controller.eventStore = Self.store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}
