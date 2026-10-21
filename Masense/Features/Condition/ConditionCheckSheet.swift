import SwiftData
import SwiftUI

/// S3 컨디션 체크. 증상 10개 칩 → 탭하면 0~3 강도 선택. 대처법은 안내하지 않는다 (COMPLIANCE.md 2.1-7).
struct ConditionCheckSheet: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var model: ConditionCheckModel
    @State private var focused: Symptom?

    init(dose: Dose, window: ConditionWindow, onSaved: @escaping () -> Void = {}) {
        _model = State(initialValue: ConditionCheckModel(dose: dose, window: window))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    symptoms
                    appetite
                    memo
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s4)
            }
            .background(Color.midnightElevated)
            .safeAreaInset(edge: .bottom) {
                if model.hasSevereSymptom {
                    NoticeLine("symptom.severe")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.vertical, Spacing.s3)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(Text(LocalizedStringKey(model.window.titleKey)))
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

    private var symptoms: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            sectionTitle("condition.symptoms")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.s2) {
                ForEach(Symptom.allCases) { symptom in
                    SymptomChip(
                        title: symptom.localizedName,
                        severity: model.severity(of: symptom),
                        isFocused: focused == symptom
                    ) {
                        focused = focused == symptom ? nil : symptom
                    }
                }
            }
            if let focused {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text(focused.localizedName)
                        .font(Typography.label)
                        .foregroundStyle(Color.ink)
                    Picker(
                        focused.localizedName,
                        selection: Binding(
                            get: { model.severity(of: focused) },
                            set: { model.setSeverity($0, for: focused) }
                        )
                    ) {
                        ForEach(SymptomEntry.severityRange, id: \.self) { value in
                            Text(SymptomChip.severityLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var appetite: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            sectionTitle("condition.appetite")
            Picker("condition.appetite", selection: $model.appetite) {
                ForEach(AppetiteLevel.allCases, id: \.self) { level in
                    Text(LocalizedStringKey(level.titleKey)).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var memo: some View {
        TextField("field.memo", text: $model.note, axis: .vertical)
            .lineLimit(2...5)
            .padding(Spacing.s3)
            .background(Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .stroke(Color.frostBorder, lineWidth: 1)
            )
            .foregroundStyle(Color.ink)
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Typography.label)
            .foregroundStyle(Color.inkSecondary)
    }

    private func save() {
        guard (try? model.save(in: context)) != nil else { return }
        Task { await services.refreshNotifications(context: context) }
        dismiss()
        onSaved()
    }
}
