import SwiftData
import SwiftUI

/// S7 단백질 채우기. 끼니 선택 → 식품 칩(수량) → "대략 n g". 경고·색 변화 없음 (R9).
struct ProteinSheet: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model: ProteinLogModel

    init(model: ProteinLogModel, onSaved: @escaping () -> Void = {}) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Picker("protein.meal", selection: $model.meal) {
                        ForEach(MealSlot.allCases) { meal in
                            Text(LocalizedStringKey(meal.titleKey)).tag(meal)
                        }
                    }
                    .pickerStyle(.segmented)

                    if model.isLowCondition {
                        // R10 식욕 저하일: 작게 자주. 식품 종류만, 양·칼로리 없음
                        VStack(alignment: .leading, spacing: Spacing.s3) {
                            sectionTitle("daily.smallFrequent")
                            LazyVGrid(columns: columns, spacing: Spacing.s2) {
                                ForEach(ProteinRules.smallFrequentFoods) { food in
                                    foodChip(food)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.s3) {
                        sectionTitle("protein.foods")
                        LazyVGrid(columns: columns, spacing: Spacing.s2) {
                            ForEach(ProteinFood.allCases) { food in
                                foodChip(food)
                            }
                        }
                    }

                    let selected = ProteinFood.allCases.filter { model.quantity(of: $0) > 0 }
                    if !selected.isEmpty {
                        VStack(spacing: Spacing.s2) {
                            ForEach(selected) { food in
                                Stepper(
                                    value: Binding(get: { model.quantity(of: food) }, set: { model.setQuantity($0, for: food) }),
                                    in: ProteinLogModel.quantityRange
                                ) {
                                    LabeledContent(LocalizedStringKey(food.titleKey)) {
                                        Text(model.quantity(of: food), format: .number).monospacedDigit()
                                    }
                                }
                            }
                            if model.quantity(of: .other) > 0 {
                                HStack {
                                    TextField("protein.otherGrams", text: $model.otherGramsText)
                                        .keyboardType(.numberPad)
                                    Text(verbatim: "g").foregroundStyle(Color.inkSecondary)
                                }
                            }
                        }
                        .foregroundStyle(Color.ink)
                    }

                    Text("protein.estimateNote")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                    if model.target == nil {
                        Text("protein.noTarget.hint")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s4)
            }
            .safeAreaInset(edge: .bottom) {
                total
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.s3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
            }
            .background(Color.midnightElevated)
            .navigationTitle("protein.title")
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

    private var total: some View {
        Group {
            if let target = model.target {
                Text("protein.total.progress \(model.todayTotal) \(target)")
            } else {
                Text("protein.total.approx \(model.estimatedGrams)")
            }
        }
        .font(Typography.label)
        .monospacedDigit()
        .foregroundStyle(Color.ink)
    }

    private func foodChip(_ food: ProteinFood) -> some View {
        let quantity = model.quantity(of: food)
        return Button {
            model.toggle(food)
        } label: {
            HStack(spacing: Spacing.s1) {
                Text(LocalizedStringKey(food.titleKey))
                    .lineLimit(2)
                Spacer(minLength: Spacing.s1)
                if quantity > 0 {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .font(Typography.label)
            .foregroundStyle(Color.ink)
            .padding(Spacing.s3)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(quantity > 0 ? Color.accentSoft : Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .stroke(quantity > 0 ? Color.accent : Color.frostBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(quantity > 0 ? .isSelected : [])
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Typography.label)
            .foregroundStyle(Color.inkSecondary)
    }

    private func save() {
        guard (try? model.save(in: context)) != nil else { return }
        dismiss()
        onSaved()
    }
}
