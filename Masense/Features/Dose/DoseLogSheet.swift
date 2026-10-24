import SwiftData
import SwiftUI

/// S2 투약 기록. 저장하면 알림을 다시 계산하고(R4) "기록했습니다." 토스트만 띄운다.
struct DoseLogSheet: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var model: DoseLogModel

    init(prescription: Prescription, initialDate: Date? = nil, onSaved: @escaping () -> Void = {}) {
        _model = State(initialValue: DoseLogModel(prescription: prescription, initialDate: initialDate))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                if let note = model.lastDoseNote {
                    // 지난 투약: 사실만 알린다. 다음 부위를 제안하지 않는다 (R6)
                    Section {
                        LastDoseNoteRow(note: note)
                    }
                    .frostRow()
                }

                Section {
                    DatePicker(
                        "dose.time",
                        selection: $model.administeredAt,
                        in: ...model.openedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                .frostRow()

                Section {
                    BodyMapView(selection: $model.site, history: model.history, lastUseBySite: model.lastUseBySite)
                        .padding(.vertical, Spacing.s3)
                } header: {
                    SectionHeaderText("dose.site")
                } footer: {
                    Text("bodymap.hint")
                }
                .frostRow()

                Section {
                    Stepper(value: $model.sequence, in: 1...max(model.totalDoses, model.sequence)) {
                        LabeledContent("dose.sequence.label") {
                            Group {
                                if model.dosesPerPen == 1 {
                                    // 1회용 펜: n회차 (패키지 m의 k번째 펜) (D7)
                                    let position = PrescriptionRules.packagePosition(sequence: model.sequence)
                                    Text("dose.sequence.package \(model.sequence) \(position.package) \(position.pen)")
                                } else {
                                    let position = model.penPosition
                                    Text("dose.sequence \(model.sequence) \(position.pen) \(position.position)")
                                }
                            }
                            .monospacedDigit()
                        }
                    }
                }
                .frostRow()

                Section {
                    TextField("field.memo", text: $model.note, axis: .vertical)
                }
                .frostRow()
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func save() {
        guard (try? model.save(in: context)) != nil else { return }
        Task {
            // 기록했으면 미뤄 둔 투약 알림은 필요 없다
            await services.notifications.cancelSnooze()
            await services.refreshReminders(context: context)
        }
        dismiss()
        onSaved()
    }
}

/// 지난 투약 / 허벅지 왼쪽 / 10월 15일 (목) · 7일 전
private struct LastDoseNoteRow: View {
    let note: LastDoseNote

    var body: some View {
        let day = note.date.formatted(.dateTime.month(.wide).day().weekday(.abbreviated))
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Text("dose.lastNote.title")
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            Text(BodySite.localizedName(note.site))
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(Color.ink)
            Group {
                if note.daysAgo == 0 {
                    Text("dose.lastNote.whenToday \(day)")
                } else {
                    Text("dose.lastNote.when \(day) \(note.daysAgo)")
                }
            }
            .font(Typography.caption)
            .foregroundStyle(Color.inkSecondary)
        }
        .padding(.vertical, Spacing.s1)
        .accessibilityElement(children: .combine)
    }
}
