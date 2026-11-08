import Foundation
import Observation
import SwiftData
import SwiftUI

/// 체중 수동 입력. 증감에 대한 평가 없이 "기록했습니다."만.
@Observable
final class WeightEntryModel {
    var measuredAt: Date
    var text: String = ""
    let openedAt: Date

    static let validRange = 20.0...400.0

    init(now: Date = Date()) {
        openedAt = now
        measuredAt = now
    }

    var kilograms: Double? { Self.parse(text) }

    /// D46 (U1 B3) 마지막 값에서 0.1 kg씩. 비어 있으면 아무것도 하지 않는다
    func step(_ delta: Double) {
        guard let current = kilograms else { return }
        let next = ((current + delta) * 10).rounded() / 10
        guard Self.validRange.contains(next) else { return }
        text = String(format: "%.1f", next)
    }

    /// 소수 1자리로 반올림. 쉼표 소수점도 받는다. 범위를 벗어나면 nil
    static func parse(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), validRange.contains(value) else { return nil }
        return (value * 10).rounded() / 10
    }

    @discardableResult
    func save(in context: ModelContext) throws -> WeightSample? {
        guard let kilograms else { return nil }
        let sample = WeightSample(measuredAt: measuredAt, kilograms: kilograms, source: .manual)
        context.insert(sample)
        try context.save()
        RecordUndo.shared.register(sample)
        return sample
    }
}

struct WeightEntrySheet: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var model = WeightEntryModel()
    @FocusState private var fieldFocused: Bool
    /// D46 마지막 측정값을 미리 채운다 (차이는 보이지 않는다, 평가 없음)
    @Query(sort: \WeightSample.measuredAt, order: .reverse) private var recent: [WeightSample]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "weight.entry.date",
                        selection: $model.measuredAt,
                        in: ...model.openedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    HStack {
                        TextField("weight.entry.placeholder", text: $model.text)
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                            .monospacedDigit()
                        Text(verbatim: "kg")
                            .foregroundStyle(Color.inkSecondary)
                    }
                    // D46 (U1 B3): 키패드 없이 ±0.1
                    HStack(spacing: Spacing.s3) {
                        stepButton("minus", label: "weight.entry.minus") { model.step(-0.1) }
                        stepButton("plus", label: "weight.entry.plus") { model.step(0.1) }
                        Spacer(minLength: 0)
                        if !recent.isEmpty {
                            Text("weight.entry.prefilled")
                                .font(Typography.caption)
                                .foregroundStyle(Color.inkTertiary)
                        }
                    }
                }
                .frostRow()
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("weight.entry.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save", action: save)
                        .disabled(model.kilograms == nil)
                }
            }
            .onAppear {
                if model.text.isEmpty, let last = recent.first?.kilograms {
                    model.text = String(format: "%.1f", (last * 10).rounded() / 10)
                } else {
                    fieldFocused = true
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func stepButton(_ systemImage: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 36)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(label))
    }

    private func save() {
        guard (try? model.save(in: context)) != nil else { return }
        // 오늘 체중을 기록했으면 오늘의 체중 알림은 필요 없다 (R4-2)
        Task { await services.refreshReminders(context: context) }
        dismiss()
        onSaved()
    }
}
