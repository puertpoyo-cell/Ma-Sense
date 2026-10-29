import PhotosUI
import SwiftData
import SwiftUI

/// 진료 직후 기록 (D20, SCREENS.md S14-1). 진료일·메모·검사지 사진·검사 결과.
/// 사진을 넣으면 기기 안에서 글자를 읽어 검사 결과 칸을 채우고, 사용자가 검사지와 맞춰 고친 뒤 저장한다.
/// 앱은 수치를 판단하지 않는다 (기준 범위·정상/높음·색 없음, COMPLIANCE.md 2.2)
struct ClinicVisitSheet: View {
    /// 검사 결과 한 줄 입력값
    struct LabRow: Identifiable, Equatable {
        let id = UUID()
        var item: LabItem
        var customName = ""
        var valueText = ""
        var unit: String
        var note = ""

        var value: Double? {
            Double(valueText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        }
    }

    /// 화면에 보이는 사진. 저장된 것은 `stored`, 이번에 넣은 것은 `image`
    struct PhotoItem: Identifiable {
        let id = UUID()
        var stored: ClinicPhoto?
        var image: UIImage
    }

    let editing: ClinicVisit?
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @State private var visitedAt: Date
    @State private var note: String
    @State private var labs: [LabRow]
    @State private var photos: [PhotoItem]
    @State private var removedPhotos: [ClinicPhoto] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsCamera = false
    @State private var readingCount = 0
    @State private var lastReadCount: Int?
    /// N-C3: 이번에 넣은 사진에서 읽힌 줄 (화면에서만, 저장하지 않음). 왜 어떤 항목이 안 채워졌는지 볼 수 있게
    @State private var readLines: [String] = []
    @State private var showsReadLines = false
    @State private var viewing: PhotoItem?
    @State private var confirmsDelete = false

    init(editing: ClinicVisit? = nil, onSaved: @escaping () -> Void = {}) {
        self.editing = editing
        self.onSaved = onSaved
        _visitedAt = State(initialValue: editing?.visitedAt ?? .now)
        _note = State(initialValue: editing?.note ?? "")
        _labs = State(initialValue: (editing?.labResults ?? []).sorted { $0.createdAt < $1.createdAt }.map {
            LabRow(item: $0.item, customName: $0.customName ?? "", valueText: Self.format($0.value), unit: $0.unit, note: $0.note ?? "")
        })
        _photos = State(initialValue: (editing?.photos ?? []).sorted { $0.createdAt < $1.createdAt }.compactMap { photo in
            photo.imageData.flatMap(UIImage.init(data:)).map { PhotoItem(stored: photo, image: $0) }
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("clinic.visit.date", selection: $visitedAt, in: ...Date.now, displayedComponents: .date)
                    TextField("clinic.visit.note.placeholder", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    SectionHeaderText("clinic.visit.section.visit")
                }
                .frostRow()

                Section {
                    if !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.s2) {
                                ForEach(photos) { photo in
                                    thumbnail(photo)
                                }
                            }
                            .padding(.vertical, Spacing.s1)
                        }
                    }
                    HStack(spacing: Spacing.s2) {
                        if CameraPicker.isAvailable {
                            Button {
                                showsCamera = true
                            } label: {
                                Label("clinic.visit.photo.camera", systemImage: "camera")
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 4, matching: .images) {
                            Label("clinic.visit.photo.library", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                    .listRowInsets(EdgeInsets(top: Spacing.s2, leading: Spacing.s4, bottom: Spacing.s2, trailing: Spacing.s4))
                    if readingCount > 0 {
                        HStack(spacing: Spacing.s2) {
                            ProgressView()
                            Text("clinic.visit.photo.reading")
                                .font(Typography.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    } else if let lastReadCount {
                        Text(lastReadCount > 0 ? "clinic.visit.photo.read \(lastReadCount)" : "clinic.visit.photo.readNone")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    if !readLines.isEmpty {
                        DisclosureGroup(isExpanded: $showsReadLines) {
                            ForEach(Array(readLines.prefix(Self.maxReadLines).enumerated()), id: \.offset) { _, line in
                                Text(verbatim: line)
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.inkSecondary)
                            }
                        } label: {
                            Text("clinic.visit.photo.readLines \(readLines.count)")
                                .font(Typography.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                } header: {
                    SectionHeaderText("clinic.visit.section.photos")
                } footer: {
                    Text("clinic.visit.photo.footer")
                }
                .frostRow()

                Section {
                    ForEach($labs) { $row in
                        labRow($row)
                    }
                    .onDelete { labs.remove(atOffsets: $0) }
                    Menu {
                        ForEach(LabItem.allCases) { item in
                            Button(LocalizedStringKey("lab.item." + item.rawValue)) {
                                labs.append(LabRow(item: item, unit: item.defaultUnit))
                            }
                        }
                    } label: {
                        Label("clinic.visit.lab.add", systemImage: "plus")
                    }
                } header: {
                    SectionHeaderText("clinic.visit.section.labs")
                } footer: {
                    Text("lab.notice")
                }
                .frostRow()

                if editing != nil {
                    Section {
                        Button("clinic.visit.delete") { confirmsDelete = true }
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .frostRow()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle(editing == nil ? "clinic.visit.new" : "clinic.visit.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save", action: save)
                        .disabled(readingCount > 0)
                }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                pickerItems = []
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                            await add(image)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                CameraPicker { image in Task { await add(image) } }
                    .ignoresSafeArea()
            }
            .sheet(item: $viewing) { photo in
                PhotoViewer(image: photo.image)
            }
            .confirmationDialog("clinic.visit.delete.confirm", isPresented: $confirmsDelete, titleVisibility: .visible) {
                // 빨강 금지: destructive 역할 없이
                Button("clinic.visit.delete", action: deleteVisit)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.midnightElevated)
    }

    // MARK: 행

    private func labRow(_ row: Binding<LabRow>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: Spacing.s2) {
                Picker(selection: row.item) {
                    ForEach(LabItem.allCases) { item in
                        Text(LocalizedStringKey("lab.item." + item.rawValue)).tag(item)
                    }
                } label: {
                    EmptyView()
                }
                .labelsHidden()
                .onChange(of: row.wrappedValue.item) { _, item in
                    if row.wrappedValue.unit.isEmpty || LabItem.allCases.contains(where: { $0.defaultUnit == row.wrappedValue.unit }) {
                        row.wrappedValue.unit = item.defaultUnit
                    }
                }
                Spacer(minLength: 0)
                TextField("clinic.visit.lab.value", text: row.valueText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Typography.body)
                    .frame(maxWidth: 80)
                TextField("clinic.visit.lab.unit", text: row.unit)
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: 90)
            }
            if row.wrappedValue.item == .custom {
                TextField("clinic.visit.lab.customName", text: row.customName)
            }
            TextField("clinic.visit.lab.note", text: row.note)
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private func thumbnail(_ photo: PhotoItem) -> some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(width: 72, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.frostBorder, lineWidth: 1))
            .onTapGesture { viewing = photo }
            .contextMenu {
                Button("clinic.visit.photo.remove") { removePhoto(photo) }
            }
            .accessibilityLabel(Text("clinic.visit.photo.a11y"))
    }

    // MARK: 동작

    /// 사진을 더하고 글자를 읽어 아직 없는 항목만 채운다
    @MainActor
    private func add(_ image: UIImage) async {
        photos.append(PhotoItem(stored: nil, image: image))
        readingCount += 1
        let lines = await TextRecognitionService.lines(in: image)
        let candidates = LabRules.candidates(lines: lines)
        readingCount -= 1
        readLines += lines
        var added = 0
        for candidate in candidates where !labs.contains(where: { $0.item == candidate.item }) {
            labs.append(LabRow(item: candidate.item, valueText: Self.format(candidate.value), unit: candidate.unit))
            added += 1
        }
        lastReadCount = added
    }

    private func removePhoto(_ photo: PhotoItem) {
        photos.removeAll { $0.id == photo.id }
        if let stored = photo.stored { removedPhotos.append(stored) }
    }

    private func save() {
        let visit = editing ?? {
            let created = ClinicVisit(visitedAt: visitedAt)
            context.insert(created)
            return created
        }()
        visit.visitedAt = visitedAt
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        visit.note = trimmed.isEmpty ? nil : trimmed

        // 검사 결과는 입력값으로 다시 만든다 (값이 없는 줄은 버린다)
        (visit.labResults ?? []).forEach { context.delete($0) }
        let measuredAt = calendar.startOfDay(for: visitedAt)
        for row in labs {
            guard let value = row.value else { continue }
            let name = row.customName.trimmingCharacters(in: .whitespaces)
            if row.item == .custom, name.isEmpty { continue }
            let note = row.note.trimmingCharacters(in: .whitespaces)
            let result = LabResult(
                measuredAt: measuredAt,
                item: row.item,
                customName: row.item == .custom ? name : nil,
                value: value,
                unit: row.unit.trimmingCharacters(in: .whitespaces),
                note: note.isEmpty ? nil : note
            )
            context.insert(result)
            result.visit = visit
        }

        removedPhotos.forEach { context.delete($0) }
        for photo in photos where photo.stored == nil {
            let stored = ClinicPhoto(imageData: photo.image.jpegForStorage())
            context.insert(stored)
            stored.visit = visit
        }
        try? context.save()
        onSaved()
        dismiss()
    }

    private func deleteVisit() {
        if let editing { context.delete(editing) }
        try? context.save()
        dismiss()
    }

    /// 읽은 글자 미리 보기 최대 줄 수
    static let maxReadLines = 60

    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

/// 검사지 사진 크게 보기 (핀치로 확대)
struct PhotoViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * scale)
            }
            .gesture(MagnifyGesture().onChanged { scale = min(max($0.magnification, 1), 4) })
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
        }
    }
}
