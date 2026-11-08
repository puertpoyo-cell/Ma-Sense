import SwiftData
import SwiftUI

/// S7 단백질 채우기. 끼니 선택 → 식품 칩(수량) → "대략 n g". 경고·색 변화 없음 (R9).
struct ProteinSheet: View {
    var onSaved: () -> Void = {}
    /// D20 사진으로 확인해 기록했을 때 대략 g
    var onPhotoSaved: (Int) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model: ProteinLogModel
    @State private var showsPhoto = false
    /// D46 최근 조합 (새 기록 순)
    @Query(sort: \ProteinEntry.createdAt, order: .reverse) private var recentEntries: [ProteinEntry]
    @Environment(\.calendar) private var calendar

    init(model: ProteinLogModel, onSaved: @escaping () -> Void = {}, onPhotoSaved: @escaping (Int) -> Void = { _ in }) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
        self.onPhotoSaved = onPhotoSaved
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

                    // D46 (U1 B2): 최근에 먹은 조합을 한 번에 (같은 끼니로 오늘 기록)
                    let combos = ProteinRules.recentCombos(recentEntries.prefix(40).map(\.snapshot))
                    if !combos.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            sectionTitle("protein.recent")
                            ForEach(Array(combos.enumerated()), id: \.offset) { _, combo in
                                Button { saveAgain(combo) } label: {
                                    HStack(spacing: Spacing.s2) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .foregroundStyle(Color.accent)
                                            .accessibilityHidden(true)
                                        Text(verbatim: combo.foods.map { L10n.string($0.titleKey) }.joined(separator: " · "))
                                            .font(Typography.label)
                                            .foregroundStyle(Color.ink)
                                            .lineLimit(1)
                                        Spacer(minLength: Spacing.s2)
                                        Text("protein.recent.grams \(combo.estimatedGrams)")
                                            .font(Typography.caption)
                                            .monospacedDigit()
                                            .foregroundStyle(Color.inkSecondary)
                                    }
                                    .padding(Spacing.s3)
                                    .background(Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(Text("protein.recent.hint"))
                            }
                        }
                    }

                    // D20 사진으로 확인: 종류만 짐작하고 양은 다시 묻는다
                    Button {
                        showsPhoto = true
                    } label: {
                        HStack(spacing: Spacing.s2) {
                            CoachFace(size: 32)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("foodPhoto.entry")
                                    .font(Typography.label)
                                    .foregroundStyle(Color.ink)
                                Text("foodPhoto.entry.detail")
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "camera")
                                .foregroundStyle(Color.accent)
                                .accessibilityHidden(true)
                        }
                        .padding(Spacing.s3)
                        .background(Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).stroke(Color.frostBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    if model.isLowAppetite {
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
        .sheet(isPresented: $showsPhoto) {
            FoodPhotoSheet(meal: model.meal) { grams in
                dismiss()
                onPhotoSaved(grams)
            }
        }
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

    /// D46 최근 조합을 고른 끼니로 오늘 다시 기록
    private func saveAgain(_ combo: ProteinEntrySnapshot) {
        let entry = ProteinEntry(date: calendar.startOfDay(for: .now), meal: model.meal, foods: combo.foods, estimatedGrams: combo.estimatedGrams)
        context.insert(entry)
        try? context.save()
        RecordUndo.shared.register(entry)
        dismiss()
        onSaved()
    }
}
