import SwiftData
import SwiftUI
import WatchKit

/// D51 워치에서 컨디션 체크 (투약 후 24·48시간). 증상을 누를 때마다 강도가 0 → 1 → 2 → 3 → 0으로 돈다.
/// 고른 그대로 저장하고 판단·대처 안내는 하지 않는다 (COMPLIANCE.md 2.1-7). 메모는 iPhone에서
struct WatchConditionView: View {
    let dose: Dose
    let window: ConditionWindow

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var severities: [Symptom: Int] = [:]
    @State private var appetite: AppetiteLevel = .normal
    @State private var saved = false

    var body: some View {
        List {
            if saved {
                Label("toast.recorded", systemImage: "checkmark.circle.fill")
            }
            Section {
                ForEach(Symptom.allCases) { symptom in
                    let value = severities[symptom] ?? 0
                    Button {
                        severities[symptom] = ConditionRules.nextSeverity(after: value)
                    } label: {
                        HStack {
                            Text(verbatim: symptom.localizedName)
                            Spacer()
                            Text(LocalizedStringKey("severity.\(value)"))
                                .font(.caption)
                                .foregroundStyle(value == 0 ? .secondary : .primary)
                        }
                    }
                    .accessibilityValue(Text(LocalizedStringKey("severity.\(value)")))
                }
            } header: {
                Text("condition.symptoms")
            }
            Section {
                Picker("condition.appetite", selection: $appetite) {
                    ForEach(AppetiteLevel.allCases, id: \.self) { level in
                        Text(LocalizedStringKey(level.titleKey)).tag(level)
                    }
                }
            }
            if severities.values.contains(where: { $0 >= 3 }) {
                Text("symptom.severe")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("action.save", action: save)
                .disabled(saved)
        }
        .navigationTitle(Text(LocalizedStringKey(window.titleKey)))
    }

    private func save() {
        let entries = Symptom.allCases.compactMap { symptom -> SymptomEntry? in
            let value = severities[symptom] ?? 0
            return value > 0 ? SymptomEntry(symptom: symptom, severity: value) : nil
        }
        let check = ConditionCheck(checkedAt: .now, window: window, symptoms: entries, appetite: appetite)
        context.insert(check)
        check.dose = dose
        try? context.save()
        WKInterfaceDevice.current().play(.success)
        saved = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        }
    }
}
