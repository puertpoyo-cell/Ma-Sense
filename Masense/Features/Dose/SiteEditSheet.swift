import SwiftData
import SwiftUI

/// 부위 기록 없음으로 저장한 투약의 부위를 나중에 고친다 (D6, SCREENS.md S4). 기록 탭에서 연다.
struct SiteEditSheet: View {
    let dose: Dose
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allDoses: [Dose]
    @State private var site: BodySite?

    init(dose: Dose, onSaved: @escaping () -> Void = {}) {
        self.dose = dose
        self.onSaved = onSaved
        _site = State(initialValue: dose.site)
    }

    var body: some View {
        // 부위는 몸 기준이라 모든 처방의 기록을 본다 (R6)
        let snapshots = allDoses.map(\.snapshot)
        NavigationStack {
            Form {
                Section {
                    Text(dose.administeredAt.formatted(.dateTime.month(.wide).day().weekday(.abbreviated)))
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(Color.ink)
                }
                .frostRow()

                Section {
                    BodyMapView(
                        selection: $site,
                        history: SiteRules.siteHistory(doses: snapshots),
                        lastUseBySite: SiteRules.lastUseBySite(doses: snapshots)
                    )
                    .padding(.vertical, Spacing.s3)
                } header: {
                    SectionHeaderText("dose.site")
                } footer: {
                    Text("bodymap.hint")
                }
                .frostRow()
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("site.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save", action: save)
                        .disabled(site == nil)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func save() {
        guard let site else { return }
        dose.site = site
        try? context.save()
        dismiss()
        onSaved()
    }
}
