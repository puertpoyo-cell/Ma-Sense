import SwiftData
import SwiftUI

/// 지난 투약 한꺼번에 입력 (D6, SCREENS.md S2-1). 처방 시작일 이후 기록이 없는 주를 나열하고 켜 둔 주만 예정 일시로 기록한다.
/// 부위를 모르면 비워 둔다. 기록 탭에서 나중에 고칠 수 있다.
struct BackfillSheet: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var model: BackfillModel

    init(prescription: Prescription, onSaved: @escaping () -> Void = {}) {
        _model = State(initialValue: BackfillModel(prescription: prescription))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("backfill.intro \(model.startDate.formatted(.dateTime.month(.wide).day()))")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                }
                .frostRow()

                Section {
                    ForEach($model.rows) { $row in
                        rowView($row)
                    }
                } header: {
                    SectionHeaderText(Text("backfill.section \(model.rows.count)"))
                } footer: {
                    VStack(alignment: .leading, spacing: Spacing.s1) {
                        Text("backfill.footer")
                        if model.rows.count > model.remaining {
                            Text("backfill.remaining \(model.remaining)")
                        }
                        if model.renumberedCount > 0 {
                            Text("backfill.renumbered \(model.renumberedCount)")
                        }
                    }
                }
                .frostRow()
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("backfill.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("backfill.save \(model.selectedCount)", action: save)
                        .disabled(!model.canSave)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func rowView(_ row: Binding<BackfillModel.Row>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Toggle(isOn: row.isIncluded) {
                Text(row.wrappedValue.cycle.scheduledDate.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))
                    .font(Typography.body)
                    .foregroundStyle(Color.ink)
            }
            .tint(Color.accent)
            .disabled(!model.canToggle(row.wrappedValue))
            if row.wrappedValue.isIncluded {
                Picker("dose.site", selection: row.site) {
                    Text("site.unknown").tag(BodySite?.none)
                    ForEach(BodySite.allCases) { site in
                        Text(site.localizedName).tag(BodySite?.some(site))
                    }
                }
                .pickerStyle(.menu)
                .font(Typography.caption)
                .tint(Color.inkSecondary)
            }
        }
    }

    private func save() {
        guard let saved = try? model.save(in: context), saved > 0 else { return }
        Task { await services.refreshNotifications(context: context) }
        dismiss()
        onSaved()
    }
}
