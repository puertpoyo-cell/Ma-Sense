import PhotosUI
import SwiftData
import SwiftUI

/// 사진으로 단백질 확인 (D20, SCREENS.md S7-1). 사진에서 음식 종류만 짐작하고, 양은 마선생이 다시 묻는다
/// ("달걀이 보여요. 몇 개 드셨어요?"). 사진은 저장하지 않는다. 양·칼로리 판정 없음 (COMPLIANCE.md 2.1-3·2.1-6)
struct FoodPhotoSheet: View {
    /// 짐작했거나 사용자가 고른 식품 한 줄
    struct Portion: Identifiable, Equatable {
        var id: ProteinFood { food }
        let food: ProteinFood
        var unit: FoodPhotoRules.PortionUnit
        var amount: Double
    }

    private enum Phase: Equatable {
        case pick
        case reading
        case ask
    }

    let meal: MealSlot
    /// 저장한 대략 g을 넘긴다 (마선생 "약 n g")
    var onSaved: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @State private var selectedMeal: MealSlot
    @State private var phase: Phase = .pick
    @State private var image: UIImage?
    @State private var portions: [Portion] = []
    @State private var guessedNothing = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showsCamera = false

    init(meal: MealSlot, onSaved: @escaping (Int) -> Void) {
        self.meal = meal
        self.onSaved = onSaved
        _selectedMeal = State(initialValue: meal)
    }

    private var totalGrams: Int {
        FoodPhotoRules.grams(portions.map { ($0.food, $0.unit, $0.amount) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .accessibilityHidden(true)
                    }
                    switch phase {
                    case .pick: pickButtons
                    case .reading: reading
                    case .ask: askSection
                    }
                    Text("foodPhoto.footer")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s4)
            }
            .safeAreaInset(edge: .bottom) {
                if phase == .ask {
                    Text("protein.total.approx \(totalGrams)")
                        .font(Typography.label)
                        .monospacedDigit()
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.vertical, Spacing.s3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                }
            }
            .background(Color.midnightElevated)
            .navigationTitle("foodPhoto.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.record", action: save)
                        .disabled(phase != .ask || portions.isEmpty)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                pickerItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let picked = UIImage(data: data) {
                        await look(at: picked)
                    }
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                CameraPicker { picked in Task { await look(at: picked) } }
                    .ignoresSafeArea()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    // MARK: 단계

    private var pickButtons: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            coachBubble(Text("foodPhoto.prompt"), mood: .smile)
            if CameraPicker.isAvailable {
                Button {
                    showsCamera = true
                } label: {
                    Label("foodPhoto.camera", systemImage: "camera")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("foodPhoto.library", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    private var reading: some View {
        HStack(spacing: Spacing.s2) {
            ProgressView()
            Text("foodPhoto.reading")
                .font(Typography.body)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private var askSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            coachBubble(question, mood: .thinking)

            Picker("protein.meal", selection: $selectedMeal) {
                ForEach(MealSlot.allCases) { meal in
                    Text(LocalizedStringKey(meal.titleKey)).tag(meal)
                }
            }
            .pickerStyle(.segmented)

            ForEach($portions) { $portion in
                portionRow($portion)
            }

            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text(portions.isEmpty ? "foodPhoto.pickFoods" : "foodPhoto.otherFoods")
                    .font(Typography.label)
                    .foregroundStyle(Color.inkSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.s2) {
                    ForEach(ProteinFood.allCases.filter { $0 != .other }) { food in
                        foodChip(food)
                    }
                }
            }
            Text("protein.estimateNote")
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    /// 짐작한 첫 식품으로 묻는다. 못 찾았으면 골라 달라고
    private var question: Text {
        guard let first = portions.first, !guessedNothing else { return Text("foodPhoto.guessedNothing") }
        let name = L10n.string(first.food.titleKey)
        // "달걀, 맞나요?" + 단위별로 다시 묻기 ("몇 개 드셨어요?", "몇 숟갈 드셨어요?")
        return Text("foodPhoto.question \(name)") + Text(verbatim: " ") + Text(LocalizedStringKey("food.ask." + first.unit.key))
    }

    private func portionRow(_ portion: Binding<Portion>) -> some View {
        let units = FoodPhotoRules.units(for: portion.wrappedValue.food)
        return VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack {
                Text(LocalizedStringKey(portion.wrappedValue.food.titleKey))
                    .font(Typography.label)
                    .foregroundStyle(Color.ink)
                Spacer()
                if units.count > 1 {
                    Picker("foodPhoto.unit", selection: portion.unit) {
                        ForEach(units, id: \.self) { unit in
                            Text(LocalizedStringKey("food.unit." + unit.key)).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 160)
                    .onChange(of: portion.wrappedValue.unit) { _, unit in
                        portion.wrappedValue.amount = FoodPhotoRules.defaultAmount(for: unit)
                    }
                }
            }
            Stepper(value: portion.amount, in: 0...20, step: portion.wrappedValue.unit.step) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s1) {
                    Text(portion.wrappedValue.amount.formatted(.number.precision(.fractionLength(0...1))))
                        .font(Typography.metricLarge)
                        .monospacedDigit()
                        .foregroundStyle(Color.ink)
                    Text(LocalizedStringKey("food.unit." + portion.wrappedValue.unit.key))
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .padding(Spacing.s3)
        .background(Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    private func foodChip(_ food: ProteinFood) -> some View {
        let isOn = portions.contains { $0.food == food }
        return Button {
            if isOn {
                portions.removeAll { $0.food == food }
            } else if let unit = FoodPhotoRules.units(for: food).first {
                portions.append(Portion(food: food, unit: unit, amount: FoodPhotoRules.defaultAmount(for: unit)))
            }
        } label: {
            Text(LocalizedStringKey(food.titleKey))
                .font(Typography.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isOn ? Color.accentSoft : Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).stroke(isOn ? Color.accent : Color.frostBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// 마선생 얼굴 + 말풍선 (팝업과 같은 모양을 시트 안에 고정)
    private func coachBubble(_ text: Text, mood: CoachMood) -> some View {
        HStack(alignment: .bottom, spacing: Spacing.s2) {
            CoachFace(size: 48, mood: mood)
                .accessibilityHidden(true)
            text
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6, bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous)
                        .fill(Color.frost)
                )
        }
    }

    // MARK: 동작

    @MainActor
    private func look(at picked: UIImage) async {
        image = picked
        phase = .reading
        let foods = await FoodRecognitionService.foods(in: picked)
        guessedNothing = foods.isEmpty
        portions = foods.compactMap { food in
            FoodPhotoRules.units(for: food).first.map { Portion(food: food, unit: $0, amount: FoodPhotoRules.defaultAmount(for: $0)) }
        }
        phase = .ask
    }

    /// 사진은 버리고 식품·대략 g만 단백질 기록으로 남긴다. 기록 시각이 `now` 주입 지점
    private func save() {
        let grams = totalGrams
        let foods = portions.filter { $0.amount > 0 }.map(\.food)
        guard !foods.isEmpty else { return }
        let entry = ProteinEntry(date: calendar.startOfDay(for: .now), meal: selectedMeal, foods: foods, estimatedGrams: grams)
        context.insert(entry)
        try? context.save()
        dismiss()
        onSaved(grams)
    }
}
