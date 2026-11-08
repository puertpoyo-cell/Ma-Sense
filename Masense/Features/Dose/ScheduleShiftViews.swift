import SwiftData
import SwiftUI

// D45 투약 일정 옮기기 (2026-11-08 사람 요청 "주기 조정이랑 먼저 맞은 거 수정하는 게 어렵다").
// 늦거나 일찍 맞은 기록에서 바로 "다음부터 이 요일로", 오늘 화면 예정 시간 칸에서 바로 요일·시각 바꾸기

extension Prescription {
    /// 요일·시각·(필요하면) 시작일만 바꾼다. 기록·펜 수는 그대로
    func applySchedule(_ snapshot: PrescriptionSnapshot) {
        startDate = snapshot.startDate
        scheduledWeekday = snapshot.scheduledWeekday
        scheduledHour = snapshot.scheduledHour
        scheduledMinute = snapshot.scheduledMinute
    }
}

/// 투약 기록·투약 고치기 안에 들어가는 "다음부터 이 요일로" 한 칸. 예정과 다른 날일 때만 보인다
struct ScheduleShiftSection: View {
    let offset: Int
    let administeredAt: Date
    /// 켰을 때의 다음 예정 일시
    let preview: Date?
    @Binding var isOn: Bool

    var body: some View {
        let weekday = administeredAt.formatted(.dateTime.weekday(.wide))
        Section {
            Toggle(isOn: $isOn) {
                Text("schedule.shift.toggle \(weekday)")
                    .foregroundStyle(Color.ink)
            }
            .tint(Color.accent)
            if isOn, let preview {
                LabeledContent("schedule.shift.next") {
                    Text(verbatim: ScheduleFormat.text(preview))
                        .monospacedDigit()
                        .foregroundStyle(Color.ink)
                }
            }
        } header: {
            SectionHeaderText("schedule.shift.header")
        } footer: {
            if offset > 0 {
                Text("schedule.shift.footer.late \(offset)")
            } else {
                Text("schedule.shift.footer.early \(-offset)")
            }
        }
        .frostRow()
    }
}

enum ScheduleFormat {
    /// "11. 16. (월) 오후 8:00"
    static func text(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)) + " " + date.formatted(date: .omitted, time: .shortened)
    }
}

/// 오늘 화면 "예정 시간" 칸을 눌러 여는 일정 바꾸기. 요일 일곱 칸 + 30분 단위 시각 + 다음 투약 미리 보기
struct ScheduleSheet: View {
    let prescription: Prescription
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @Environment(\.calendar) private var calendar
    @State private var weekday: Int
    @State private var time: Date

    init(prescription: Prescription, onSaved: @escaping () -> Void = {}) {
        self.prescription = prescription
        self.onSaved = onSaved
        _weekday = State(initialValue: prescription.scheduledWeekday)
        _time = State(initialValue: Calendar.current.date(
            bySettingHour: prescription.scheduledHour, minute: prescription.scheduledMinute, second: 0, of: .now
        ) ?? .now)
    }

    private var planned: PrescriptionSnapshot {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        let doses = prescription.doseSnapshots
        let anchor = doses.filter { !$0.isCancelled }.map(\.administeredAt).max() ?? .now
        return ScheduleShiftRules.shifted(
            prescription.snapshot, doses: doses, weekday: weekday,
            hour: parts.hour ?? prescription.scheduledHour, minute: parts.minute ?? 0,
            anchor: anchor, calendar: calendar
        )
    }

    var body: some View {
        let symbols = calendar.shortWeekdaySymbols
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: Spacing.s1) {
                        ForEach(order, id: \.self) { day in
                            let selected = day == weekday
                            Button {
                                weekday = day
                            } label: {
                                Text(verbatim: symbols[day - 1])
                                    .font(Typography.label)
                                    .foregroundStyle(selected ? Color.midnight : Color.ink)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(selected ? Color.accent : Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, Spacing.s1)
                    HalfHourDatePicker(selection: $time, mode: .time)
                        .frame(maxWidth: .infinity)
                } header: {
                    SectionHeaderText("schedule.sheet.when")
                }
                .frostRow()

                Section {
                    LabeledContent("schedule.shift.next") {
                        Text(verbatim: ScheduleShiftRules.upcoming(planned, doses: prescription.doseSnapshots, now: .now, calendar: calendar).map(ScheduleFormat.text) ?? "–")
                            .monospacedDigit()
                            .foregroundStyle(Color.ink)
                    }
                } footer: {
                    Text("schedule.sheet.footer")
                }
                .frostRow()
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("schedule.sheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save", action: save)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func save() {
        prescription.applySchedule(planned)
        try? context.save()
        Task { await services.refreshReminders(context: context) }
        dismiss()
        onSaved()
    }
}
