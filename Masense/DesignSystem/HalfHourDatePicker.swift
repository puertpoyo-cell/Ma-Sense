import SwiftUI
import UIKit

/// 30분 단위 날짜·시각 고르기 (D25, DoseTimeRules). SwiftUI `DatePicker`에는 분 간격이 없어 `UIDatePicker`를 감싼다.
/// 접힌 모양(compact): 누르면 시스템 달력·휠이 뜨고 분은 :00·:30만 고를 수 있다
struct HalfHourDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    var maximum: Date?
    var mode: UIDatePicker.Mode = .dateAndTime

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.preferredDatePickerStyle = .compact
        picker.datePickerMode = mode
        picker.minuteInterval = DoseTimeRules.stepMinutes
        picker.tintColor = UIColor(Color.accent)
        picker.setContentHuggingPriority(.required, for: .horizontal)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.parent = self
        picker.maximumDate = maximum
        if picker.date != selection { picker.date = selection }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        var parent: HalfHourDatePicker
        init(parent: HalfHourDatePicker) { self.parent = parent }

        @objc func changed(_ picker: UIDatePicker) {
            let rounded = DoseTimeRules.roundedDown(picker.date, calendar: picker.calendar ?? .current)
            if rounded != parent.selection { parent.selection = rounded }
        }
    }
}
