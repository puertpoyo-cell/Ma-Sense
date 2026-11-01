import SwiftData
import SwiftUI

/// D27 새 펜 받음 (2026-11-01 사람 요청 "진료 후 세트 추가로 받음, 첫 페이지 남은 수 업데이트").
/// 같은 처방으로 패키지를 더 받았을 때 펜 수만 늘린다. 처방(시작일·요일·메모)이 바뀌었으면 새 처방으로 적는다.
/// 진료 직후에 여는 경우가 많아 다음 진료일도 같이 고칠 수 있다
struct RefillSheet: View {
    let prescription: Prescription
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var packages = 1
    @State private var hasNextClinic: Bool
    @State private var nextClinic: Date
    @State private var showsNewPrescription = false

    init(prescription: Prescription, onSaved: @escaping () -> Void = {}) {
        self.prescription = prescription
        self.onSaved = onSaved
        _hasNextClinic = State(initialValue: prescription.nextClinicDate != nil)
        _nextClinic = State(initialValue: prescription.nextClinicDate
            ?? Calendar.current.date(byAdding: .day, value: 28, to: .now) ?? .now)
    }

    private var status: PenStatus {
        PrescriptionRules.penStatus(p: prescription.snapshot, doses: prescription.doseSnapshots)
    }

    private var isSingleUse: Bool { prescription.dosesPerPen == 1 }

    private var newPenCount: Int {
        PrescriptionRules.penCount(afterAdding: packages, to: prescription.penCount, dosesPerPen: prescription.dosesPerPen)
    }

    /// 지금 남은 수 → 더한 뒤 남은 수 (1회용은 펜, 여러 회 펜은 회차)
    private var remainingNow: Int { isSingleUse ? status.remainingPens : status.remainingDoses }
    private var remainingAfter: Int {
        remainingNow + (newPenCount - prescription.penCount) * prescription.dosesPerPen
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $packages, in: 1...6) {
                        LabeledContent("refill.packages") {
                            Text(isSingleUse ? "refill.packages.singleUse \(packages) \(packages * PrescriptionRules.dosesPerPackage)" : "refill.packages.multiDose \(packages)")
                                .monospacedDigit()
                        }
                    }
                    LabeledContent("refill.remaining") {
                        Text(isSingleUse ? "refill.remaining.pens \(remainingNow) \(remainingAfter)" : "refill.remaining.doses \(remainingNow) \(remainingAfter)")
                            .monospacedDigit()
                            .foregroundStyle(Color.ink)
                    }
                } footer: {
                    Text("refill.footer")
                }
                .frostRow()

                Section {
                    Toggle("prescription.hasNextClinic", isOn: $hasNextClinic)
                    if hasNextClinic {
                        DatePicker("prescription.nextClinic", selection: $nextClinic, displayedComponents: .date)
                    }
                }
                .frostRow()

                Section {
                    Button("refill.changedPrescription") { showsNewPrescription = true }
                } footer: {
                    Text("refill.changedPrescription.footer")
                }
                .frostRow()
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("refill.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save", action: save)
                }
            }
            .sheet(isPresented: $showsNewPrescription, onDismiss: { dismiss() }) {
                PrescriptionSheet()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func save() {
        prescription.penCount = newPenCount
        prescription.nextClinicDate = hasNextClinic ? Calendar.current.startOfDay(for: nextClinic) : nil
        guard (try? context.save()) != nil else { return }
        Task { await services.refreshReminders(context: context) }
        dismiss()
        onSaved()
    }
}
