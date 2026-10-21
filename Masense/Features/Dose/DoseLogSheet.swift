import SwiftData
import SwiftUI

/// S2 투약 기록. 저장하면 알림을 다시 계산하고(R4) "기록했습니다." 토스트만 띄운다.
struct DoseLogSheet: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var model: DoseLogModel

    init(prescription: Prescription, onSaved: @escaping () -> Void = {}) {
        _model = State(initialValue: DoseLogModel(prescription: prescription))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "dose.time",
                        selection: $model.administeredAt,
                        in: ...model.openedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section {
                    BodyMapView(selection: $model.site, history: model.history)
                        .padding(.vertical, Spacing.s3)
                } header: {
                    Text("dose.site")
                } footer: {
                    Text("bodymap.hint")
                }

                Section {
                    Stepper(value: $model.sequence, in: 1...max(model.totalDoses, model.sequence)) {
                        LabeledContent("dose.sequence.label") {
                            let position = model.penPosition
                            Text("dose.sequence \(model.sequence) \(position.pen) \(position.position)")
                                .monospacedDigit()
                        }
                    }
                }

                Section {
                    TextField("field.memo", text: $model.note, axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("action.logDose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save", action: save)
                        .disabled(!model.canSave)
                }
            }
        }
        .presentationBackground(Color.midnightElevated)
    }

    private func save() {
        guard (try? model.save(in: context)) != nil else { return }
        Task { await services.refreshNotifications(context: context) }
        dismiss()
        onSaved()
    }
}
