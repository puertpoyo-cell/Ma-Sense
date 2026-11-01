import SwiftUI
import UIKit

/// 30분 단위 날짜·시각 고르기 (D25, DoseTimeRules). SwiftUI `DatePicker`에는 분 간격이 없어 `UIDatePicker`를 감싼다.
/// 휠 모양: 분은 :00·:30만 고를 수 있다. 화면에는 늘 글자로 시각을 보이고, 누르면 이 휠을 펼친다
struct HalfHourDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    var maximum: Date?
    var mode: UIDatePicker.Mode = .dateAndTime
    /// 빌드 35 실기기: 접힌 모양(compact)은 SwiftUI 줄 안에서 폭이 0으로 잡혀 시각이 안 보였다. 휠을 기본으로
    var style: UIDatePickerStyle = .wheels

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.preferredDatePickerStyle = style
        picker.locale = Locale.current
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

    /// UIKit 고유 크기를 SwiftUI에 알려 준다 (폭은 제안받은 만큼, 높이는 피커 고유 높이)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIDatePicker, context: Context) -> CGSize? {
        let fitting = uiView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(width: proposal.width ?? fitting.width, height: max(fitting.height, style == .wheels ? 180 : 34))
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
