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
        return sample
    }
}

struct WeightEntrySheet: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model = WeightEntryModel()
    @FocusState private var fieldFocused: Bool

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
                }
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
            .onAppear { fieldFocused = true }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.midnightElevated)
    }

    private func save() {
        guard (try? model.save(in: context)) != nil else { return }
        dismiss()
        onSaved()
    }
}
