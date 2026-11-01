import SwiftData
import SwiftUI

/// D33 남은 수 맞추기 (2026-11-01 사람 요청 "꼬였을 때 쉽게 고치는 방법").
/// 손에 남은 펜(1회용)·회차(여러 회 펜)를 직접 맞춘다. 쓴 회차는 투약 기록에서 오므로 그대로, 전체 펜 수만 바뀐다
struct RemainingPensSheet: View {
    let prescription: Prescription
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var remaining: Int

    init(prescription: Prescription, onSaved: @escaping () -> Void = {}) {
        self.prescription = prescription
        self.onSaved = onSaved
        _remaining = State(initialValue: prescription.remainingDoses)
    }

    private var isSingleUse: Bool { prescription.dosesPerPen == 1 }

    private var newPenCount: Int {
        PrescriptionRules.penCount(remaining: remaining, usedDoses: prescription.usedDoses, dosesPerPen: prescription.dosesPerPen)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $remaining, in: 0...(isSingleUse ? 96 : 80)) {
                        LabeledContent(isSingleUse ? "remaining.pens.label" : "remaining.doses.label") {
                            Text(verbatim: "\(remaining)")
                                .font(Typography.metricLarge)
                                .monospacedDigit()
                                .foregroundStyle(Color.ink)
                        }
                    }
                    LabeledContent("remaining.used") {
                        Text("remaining.used.value \(prescription.usedDoses)")
                            .monospacedDigit()
                    }
                } footer: {
                    Text("remaining.footer")
                }
                .frostRow()
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("remaining.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        prescription.penCount = newPenCount
                        try? context.save()
                        Task { await services.refreshReminders(context: context) }
                        dismiss()
                        onSaved()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }
}
