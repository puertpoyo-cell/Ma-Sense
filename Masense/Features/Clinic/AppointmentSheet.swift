import SwiftData
import SwiftUI

/// D28 다음 진료 예약: 날짜와(정했으면) 시각. 저장하면 진료 알림을 다시 맞춘다.
/// 시각을 정하면 당일 알림을 2시간 전에 보낼 수 있고, 캘린더에도 그 시각으로 넣는다
struct AppointmentSheet: View {
    let prescription: Prescription
    var onSaved: (Date?) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @Environment(\.calendar) private var calendar
    @State private var day: Date
    @State private var hasTime: Bool
    @State private var time: Date

    init(prescription: Prescription, suggested: Date? = nil, onSaved: @escaping (Date?) -> Void = { _ in }) {
        self.prescription = prescription
        self.onSaved = onSaved
        let calendar = Calendar.current
        let current = prescription.nextClinicDate.flatMap { $0 >= calendar.startOfDay(for: .now) ? $0 : nil }
        let start = current ?? suggested ?? calendar.date(byAdding: .day, value: 28, to: .now) ?? .now
        _day = State(initialValue: start)
        _hasTime = State(initialValue: current.map { ClinicRules.hasTime($0, calendar: calendar) } ?? false)
        _time = State(initialValue: current.flatMap { ClinicRules.hasTime($0, calendar: calendar) ? $0 : nil }
            ?? calendar.date(bySettingHour: 10, minute: 0, second: 0, of: start) ?? start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("appointment.day", selection: $day, in: calendar.startOfDay(for: .now)..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    Toggle("appointment.hasTime", isOn: $hasTime.animation())
                    if hasTime {
                        DatePicker("appointment.time", selection: $time, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("appointment.footer")
                }
                .frostRow()

                if prescription.nextClinicDate != nil {
                    Section {
                        Button("appointment.clear") {
                            prescription.nextClinicDate = nil
                            finish(nil)
                        }
                        .foregroundStyle(Color.inkSecondary)
                    }
                    .frostRow()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("appointment.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        let date = ClinicRules.appointmentDate(day: day, time: hasTime ? time : nil, calendar: calendar)
                        prescription.nextClinicDate = date
                        finish(date)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func finish(_ date: Date?) {
        try? context.save()
        Task { await services.refreshReminders(context: context) }
        dismiss()
        onSaved(date)
    }
}
