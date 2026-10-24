import SwiftData
import SwiftUI

/// S9 처방 입력 폼. "용량"이라는 단어를 레이블에 쓰지 않는다. 메모 필드일 뿐 (SCREENS.md S9).
struct PrescriptionForm: View {
    @Bindable var model: PrescriptionFormModel

    var body: some View {
        Form {
            Section {
                DatePicker("prescription.startDate", selection: $model.startDate, displayedComponents: .date)
                Picker("prescription.weekday", selection: $model.scheduledWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(model.weekdayName(weekday)).tag(weekday)
                    }
                }
                DatePicker("prescription.time", selection: $model.scheduledTime, displayedComponents: .hourAndMinute)
            }
            .frostRow()

            Section {
                Picker("prescription.penType", selection: $model.penType) {
                    Text("prescription.penType.singleUse").tag(PrescriptionFormModel.PenType.singleUse)
                    Text("prescription.penType.multiDose").tag(PrescriptionFormModel.PenType.multiDose)
                }
                if model.penType == .singleUse {
                    // 패키지 하나 = 펜 4개 = 약 한 달 (D7)
                    Stepper(value: $model.packageCount, in: PrescriptionFormModel.packageRange) {
                        LabeledContent("prescription.packageCount") {
                            Text("prescription.packageValue \(model.packageCount) \(model.penCount)").monospacedDigit()
                        }
                    }
                } else {
                    Stepper(value: $model.penCount, in: PrescriptionFormModel.multiDosePenCountRange) {
                        LabeledContent("prescription.penCount") {
                            Text(model.penCount, format: .number).monospacedDigit()
                        }
                    }
                    Stepper(value: $model.dosesPerPen, in: 2...PrescriptionFormModel.dosesPerPenRange.upperBound) {
                        LabeledContent("prescription.dosesPerPen") {
                            Text(model.dosesPerPen, format: .number).monospacedDigit()
                        }
                    }
                }
                LabeledContent("prescription.total") {
                    Text("prescription.totalValue \(model.totalDoses)").monospacedDigit()
                }
            } footer: {
                Text(LocalizedStringKey(model.penType == .singleUse ? "prescription.penType.singleUse.footer" : "prescription.penType.multiDose.footer"))
            }
            .frostRow()

            Section {
                Toggle("prescription.hasNextClinic", isOn: $model.hasNextClinicDate)
                if model.hasNextClinicDate {
                    DatePicker(
                        "prescription.nextClinic",
                        selection: $model.nextClinicDate,
                        in: model.startDate...,
                        displayedComponents: .date
                    )
                }
            }
            .frostRow()

            Section {
                TextField("prescription.memo", text: $model.doseLabel)
            } footer: {
                Text("prescription.memo.footer")
            }
            .frostRow()
        }
        .scrollContentBackground(.hidden)
        .foregroundStyle(Color.ink)
    }
}

/// 처방 입력·수정 시트. 홈 빈 상태, 설정, 처방 소진 시 연다.
struct PrescriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var model: PrescriptionFormModel

    init(editing: Prescription? = nil) {
        _model = State(initialValue: PrescriptionFormModel(editing: editing))
    }

    var body: some View {
        NavigationStack {
            PrescriptionForm(model: model)
                .background(Color.midnightElevated)
                .navigationTitle("prescription.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("action.cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("action.save", action: save)
                            .disabled(!model.isValid)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func save() {
        guard (try? model.save(in: context)) != nil else { return }
        Task { await services.refreshReminders(context: context) }
        dismiss()
    }
}

#Preview {
    Color.midnight
        .sheet(isPresented: .constant(true)) {
            PrescriptionSheet()
        }
        .modelContainer(ModelContainer.preview)
        .preferredColorScheme(.dark)
}
