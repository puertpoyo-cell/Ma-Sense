import Foundation

/// 내보내기 파일 형식 (EXPORT_FORMAT.md). 이 구조체가 형식 정의다.
/// 관계는 ID 참조로 평탄화하고, 모델의 `xxxRaw` 필드는 `Raw`를 뗀 이름의 rawValue 문자열로 쓴다.
/// rawValue를 열거형이 아닌 문자열로 두는 이유: 모르는 값이 와도 파일 전체를 거부하지 않고 모델의 기본값 규칙(DATA_MODEL.md)에 맡긴다.
struct ExportDocument: Equatable {
    static let formatIdentifier = "masense-export"
    /// 앱이 아는 최대 formatVersion. 올릴 때는 사람 확인 (CLAUDE.md) 후 이전 버전 fixture와 마이그레이션을 더한다
    static let currentFormatVersion = 1

    var format = ExportDocument.formatIdentifier
    var formatVersion = ExportDocument.currentFormatVersion
    /// "1.0.0 (12)"
    var appVersion: String
    /// SwiftData 스키마 버전 "1.0.0"
    var schemaVersion: String
    var exportedAt: Date
    var device: Device
    var settings: SettingsRecord?
    var prescriptions: [PrescriptionRecord] = []
    var doses: [DoseRecord] = []
    var conditionChecks: [ConditionCheckRecord] = []
    var weightSamples: [WeightSampleRecord] = []
    var proteinEntries: [ProteinEntryRecord] = []
    var strengthSessions: [StrengthSessionRecord] = []
    var habitChecks: [HabitCheckRecord] = []
    /// D6 (SchemaV3). 키가 없는 파일은 빈 배열로 읽는다
    var clinicQuestions: [ClinicQuestionRecord] = []

    struct Device: Codable, Equatable {
        /// "iPhone16,2"
        var model: String
        var systemVersion: String
    }

    /// `healthKitAuthorized`, `hasPurchasedPro`는 기기·계정에 종속이라 담지 않는다
    struct SettingsRecord: Codable, Equatable {
        var hasAcceptedRoleNotice: Bool
        var hasConfirmedAdult: Bool
        var reminderEnabled: Bool
        var eveningReminderHour: Int
        var conditionCheckEnabled: Bool
        var clinicReminderDaysBefore: Int
        var exhaustionReminderDosesLeft: Int
        var proteinTargetGrams: Int?
        var bodyWeightForGuideKg: Double?
        var reportTheme: String
        var reportDefaultPeriod: String?
        /// D5 (SchemaV2). 키가 없는 파일은 null로 읽는다
        var heightCm: Double?
        /// D7 (SchemaV4) 체중 기록 알림. 키가 없는 파일은 null이고 가져오면 기본값(켜짐, 투약 요일, 8:00)
        var weightReminderEnabled: Bool?
        var weightReminderWeekday: Int?
        var weightReminderHour: Int?
        var weightReminderMinute: Int?
    }

    struct PrescriptionRecord: Codable, Equatable {
        var id: UUID
        var startDate: Date
        var endDate: Date?
        var penCount: Int
        var dosesPerPen: Int
        var intervalDays: Int
        var scheduledWeekday: Int
        var scheduledHour: Int
        var scheduledMinute: Int
        var nextClinicDate: Date?
        var doseLabel: String?
        var isActive: Bool
        var createdAt: Date
    }

    struct DoseRecord: Codable, Equatable {
        var id: UUID
        /// 처방이 없는 기록이면 null. 가져오기에서 건너뛴다 (규칙 6)
        var prescriptionId: UUID?
        var administeredAt: Date
        var scheduledFor: Date
        var site: String
        var sequence: Int
        var note: String?
        var isCancelled: Bool
        var createdAt: Date
    }

    struct ConditionCheckRecord: Codable, Equatable {
        var id: UUID
        var doseId: UUID?
        var checkedAt: Date
        var window: String
        var symptoms: [SymptomRecord]
        var appetite: String
        var note: String?
        var createdAt: Date
    }

    struct SymptomRecord: Codable, Equatable {
        var symptom: String
        var severity: Int
    }

    struct WeightSampleRecord: Codable, Equatable {
        var id: UUID
        var measuredAt: Date
        var kilograms: Double
        var source: String
        var healthKitUUID: UUID?
        var leanBodyMassKg: Double?
        var createdAt: Date
    }

    struct ProteinEntryRecord: Codable, Equatable {
        var id: UUID
        var date: Date
        var meal: String
        var foods: [String]
        var estimatedGrams: Int
        var createdAt: Date
    }

    struct StrengthSessionRecord: Codable, Equatable {
        var id: UUID
        var startedAt: Date
        var durationMinutes: Int
        var kind: String
        var intensity: String
        var source: String
        var healthKitUUID: UUID?
        var note: String?
        var createdAt: Date
    }

    struct HabitCheckRecord: Codable, Equatable {
        var id: UUID
        var date: Date
        var water: Bool
        var fiber: Bool
        var sleep: Bool
        var createdAt: Date
    }

    struct ClinicQuestionRecord: Codable, Equatable {
        var id: UUID
        var text: String
        var askedAt: Date?
        var createdAt: Date
    }
}

// MARK: - Codable

extension ExportDocument: Codable {
    private enum CodingKeys: String, CodingKey {
        case format, formatVersion, appVersion, schemaVersion, exportedAt, device, settings
        case prescriptions, doses, conditionChecks, weightSamples, proteinEntries, strengthSessions, habitChecks
        case clinicQuestions
    }

    /// 배열은 키가 없어도 빈 배열로 읽는다 (M2·D6 이전 빌드가 만든 파일)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(String.self, forKey: .format)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        appVersion = try c.decode(String.self, forKey: .appVersion)
        schemaVersion = try c.decode(String.self, forKey: .schemaVersion)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        device = try c.decode(Device.self, forKey: .device)
        settings = try c.decodeIfPresent(SettingsRecord.self, forKey: .settings)
        prescriptions = try c.decodeIfPresent([PrescriptionRecord].self, forKey: .prescriptions) ?? []
        doses = try c.decodeIfPresent([DoseRecord].self, forKey: .doses) ?? []
        conditionChecks = try c.decodeIfPresent([ConditionCheckRecord].self, forKey: .conditionChecks) ?? []
        weightSamples = try c.decodeIfPresent([WeightSampleRecord].self, forKey: .weightSamples) ?? []
        proteinEntries = try c.decodeIfPresent([ProteinEntryRecord].self, forKey: .proteinEntries) ?? []
        strengthSessions = try c.decodeIfPresent([StrengthSessionRecord].self, forKey: .strengthSessions) ?? []
        habitChecks = try c.decodeIfPresent([HabitCheckRecord].self, forKey: .habitChecks) ?? []
        clinicQuestions = try c.decodeIfPresent([ClinicQuestionRecord].self, forKey: .clinicQuestions) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(format, forKey: .format)
        try c.encode(formatVersion, forKey: .formatVersion)
        try c.encode(appVersion, forKey: .appVersion)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(exportedAt, forKey: .exportedAt)
        try c.encode(device, forKey: .device)
        try c.encodeNullable(settings, forKey: .settings)
        try c.encode(prescriptions, forKey: .prescriptions)
        try c.encode(doses, forKey: .doses)
        try c.encode(conditionChecks, forKey: .conditionChecks)
        try c.encode(weightSamples, forKey: .weightSamples)
        try c.encode(proteinEntries, forKey: .proteinEntries)
        try c.encode(strengthSessions, forKey: .strengthSessions)
        try c.encode(habitChecks, forKey: .habitChecks)
        try c.encode(clinicQuestions, forKey: .clinicQuestions)
    }
}

// 비어 있는 값도 키를 지우지 않고 null로 쓴다. 사람이 파일을 열었을 때 어떤 칸이 비었는지 보이게 (EXPORT_FORMAT.md 예시와 같게)

extension ExportDocument.SettingsRecord {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hasAcceptedRoleNotice, forKey: .hasAcceptedRoleNotice)
        try c.encode(hasConfirmedAdult, forKey: .hasConfirmedAdult)
        try c.encode(reminderEnabled, forKey: .reminderEnabled)
        try c.encode(eveningReminderHour, forKey: .eveningReminderHour)
        try c.encode(conditionCheckEnabled, forKey: .conditionCheckEnabled)
        try c.encode(clinicReminderDaysBefore, forKey: .clinicReminderDaysBefore)
        try c.encode(exhaustionReminderDosesLeft, forKey: .exhaustionReminderDosesLeft)
        try c.encodeNullable(proteinTargetGrams, forKey: .proteinTargetGrams)
        try c.encodeNullable(bodyWeightForGuideKg, forKey: .bodyWeightForGuideKg)
        try c.encode(reportTheme, forKey: .reportTheme)
        try c.encodeNullable(reportDefaultPeriod, forKey: .reportDefaultPeriod)
        try c.encodeNullable(heightCm, forKey: .heightCm)
        try c.encodeNullable(weightReminderEnabled, forKey: .weightReminderEnabled)
        try c.encodeNullable(weightReminderWeekday, forKey: .weightReminderWeekday)
        try c.encodeNullable(weightReminderHour, forKey: .weightReminderHour)
        try c.encodeNullable(weightReminderMinute, forKey: .weightReminderMinute)
    }
}

extension ExportDocument.PrescriptionRecord {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(startDate, forKey: .startDate)
        try c.encodeNullable(endDate, forKey: .endDate)
        try c.encode(penCount, forKey: .penCount)
        try c.encode(dosesPerPen, forKey: .dosesPerPen)
        try c.encode(intervalDays, forKey: .intervalDays)
        try c.encode(scheduledWeekday, forKey: .scheduledWeekday)
        try c.encode(scheduledHour, forKey: .scheduledHour)
        try c.encode(scheduledMinute, forKey: .scheduledMinute)
        try c.encodeNullable(nextClinicDate, forKey: .nextClinicDate)
        try c.encodeNullable(doseLabel, forKey: .doseLabel)
        try c.encode(isActive, forKey: .isActive)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

extension ExportDocument.DoseRecord {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeNullable(prescriptionId, forKey: .prescriptionId)
        try c.encode(administeredAt, forKey: .administeredAt)
        try c.encode(scheduledFor, forKey: .scheduledFor)
        try c.encode(site, forKey: .site)
        try c.encode(sequence, forKey: .sequence)
        try c.encodeNullable(note, forKey: .note)
        try c.encode(isCancelled, forKey: .isCancelled)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

extension ExportDocument.ConditionCheckRecord {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeNullable(doseId, forKey: .doseId)
        try c.encode(checkedAt, forKey: .checkedAt)
        try c.encode(window, forKey: .window)
        try c.encode(symptoms, forKey: .symptoms)
        try c.encode(appetite, forKey: .appetite)
        try c.encodeNullable(note, forKey: .note)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

extension ExportDocument.WeightSampleRecord {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(measuredAt, forKey: .measuredAt)
        try c.encode(kilograms, forKey: .kilograms)
        try c.encode(source, forKey: .source)
        try c.encodeNullable(healthKitUUID, forKey: .healthKitUUID)
        try c.encodeNullable(leanBodyMassKg, forKey: .leanBodyMassKg)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

extension ExportDocument.StrengthSessionRecord {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(kind, forKey: .kind)
        try c.encode(intensity, forKey: .intensity)
        try c.encode(source, forKey: .source)
        try c.encodeNullable(healthKitUUID, forKey: .healthKitUUID)
        try c.encodeNullable(note, forKey: .note)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

extension ExportDocument.ClinicQuestionRecord {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encodeNullable(askedAt, forKey: .askedAt)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeNullable<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

// MARK: - 파일 읽기·쓰기, 가져오기 계획

/// 내보내기 파일 인코딩·디코딩과 가져오기 규칙 (EXPORT_FORMAT.md "가져오기 규칙"). 순수 함수.
enum ExportCodec {
    static let fileExtension = "masense.json"
    /// Info.plist `UTExportedTypeDeclarations`와 같은 값
    static let typeIdentifier = "com.puertpoyo.masense.export"

    enum ImportError: Error, Equatable {
        /// 규칙 1. "마선생 내보내기 파일이 아닙니다"
        case notMasenseExport
        /// 규칙 2. "앱을 업데이트한 뒤 가져오세요"
        case needsAppUpdate
        /// 형식 표시는 맞지만 내용을 읽을 수 없음
        case unreadable
    }

    /// 규칙 4. 기본은 교체
    enum ImportMode: String, CaseIterable {
        case replace, add
    }

    /// 규칙 9. 레코드 종류별 가져온 수·건너뛴 수
    struct ImportResult: Equatable {
        struct Count: Equatable {
            var imported = 0
            var skipped = 0
        }

        var prescriptions = Count()
        var doses = Count()
        var conditionChecks = Count()
        var weightSamples = Count()
        var proteinEntries = Count()
        var strengthSessions = Count()
        var habitChecks = Count()
        var clinicQuestions = Count()
        /// 건강 앱에서 온 체중·운동. 가져오지 않고 건강 앱에서 다시 읽는다 (건너뜀으로 세지 않는다)
        var leftToHealthApp = 0

        var totalSkipped: Int {
            [prescriptions, doses, conditionChecks, weightSamples, proteinEntries, strengthSessions, habitChecks, clinicQuestions]
                .map(\.skipped)
                .reduce(0, +)
        }
    }

    /// 실제로 저장할 레코드. 서비스가 이 순서대로 넣고 ID로 관계를 잇는다
    struct ImportPlan: Equatable {
        /// 교체 모드에서만. 추가 모드는 이 기기의 설정을 그대로 둔다
        var settings: ExportDocument.SettingsRecord?
        var prescriptions: [ExportDocument.PrescriptionRecord] = []
        var doses: [ExportDocument.DoseRecord] = []
        var conditionChecks: [ExportDocument.ConditionCheckRecord] = []
        var weightSamples: [ExportDocument.WeightSampleRecord] = []
        var proteinEntries: [ExportDocument.ProteinEntryRecord] = []
        var strengthSessions: [ExportDocument.StrengthSessionRecord] = []
        var habitChecks: [ExportDocument.HabitCheckRecord] = []
        var clinicQuestions: [ExportDocument.ClinicQuestionRecord] = []
        var result = ImportResult()
    }

    // MARK: 인코딩

    /// ISO 8601 + 소수 초 + 타임존 오프셋 (`2026-10-21T20:00:00.000+09:00`), 키 정렬, 들여쓰기
    static func encode(_ document: ExportDocument, timeZone: TimeZone) throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = timeZone
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return try encoder.encode(document)
    }

    /// 규칙 1~3. 형식 확인 → 버전 확인 → 필요하면 마이그레이션 → 디코딩
    static func decode(_ data: Data) throws -> ExportDocument {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["format"] as? String == ExportDocument.formatIdentifier
        else { throw ImportError.notMasenseExport }
        guard let version = object["formatVersion"] as? Int, version >= 1 else { throw ImportError.unreadable }
        guard version <= ExportDocument.currentFormatVersion else { throw ImportError.needsAppUpdate }

        var payload = data
        if version < ExportDocument.currentFormatVersion {
            let migrated = try ExportMigration.migrate(object, from: version)
            guard let migratedData = try? JSONSerialization.data(withJSONObject: migrated) else { throw ImportError.unreadable }
            payload = migratedData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parseDate(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "ISO 8601 날짜가 아닙니다: \(text)")
            }
            return date
        }
        do {
            return try decoder.decode(ExportDocument.self, from: payload)
        } catch {
            throw ImportError.unreadable
        }
    }

    /// 소수 초가 없는 날짜도 받는다 (사람이 고친 파일)
    static func parseDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    /// `Masense_Export_2026-10-21.masense.json`
    static func fileName(exportedAt: Date, calendar: Calendar) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: exportedAt)
        return String(format: "Masense_Export_%04d-%02d-%02d.", day.year ?? 0, day.month ?? 0, day.day ?? 0) + fileExtension
    }

    // MARK: 가져오기 계획

    /// 규칙 4~6과 건강 앱 기록 제외.
    /// - 추가 모드: `existingIDs`(이 기기에 이미 있는 레코드 ID)와 같은 ID는 건너뛴다. 파일 안에서 같은 ID가 겹쳐도 처음 것만
    /// - 처방 ID가 파일에 없는 투약은 건너뛴다. 처방을 만들어 붙이지 않는다
    /// - 컨디션 체크는 위에서 살아남은 투약에만 붙인다 (추가 모드에서 이미 있어 건너뛴 투약도 이 기기에 있으므로 붙일 수 있다)
    /// - 건강 앱에서 온 체중·운동은 넣지 않는다. 새 기기에서 건강 앱을 다시 읽으면 같은 기록이 들어온다
    /// 규칙 7(활성 처방 하나로 맞추기)은 이 기기의 처방까지 함께 봐야 하므로 저장 뒤 `PrescriptionRules.resolvingActive`로 한다.
    static func importPlan(_ document: ExportDocument, mode: ImportMode, existingIDs: Set<UUID>) -> ImportPlan {
        var plan = ImportPlan()
        var taken = mode == .add ? existingIDs : []
        func admit(_ id: UUID) -> Bool { taken.insert(id).inserted }

        if mode == .replace {
            plan.settings = document.settings
        }

        for record in document.prescriptions {
            if admit(record.id) {
                plan.prescriptions.append(record)
                plan.result.prescriptions.imported += 1
            } else {
                plan.result.prescriptions.skipped += 1
            }
        }

        let filePrescriptionIDs = Set(document.prescriptions.map(\.id))
        var reachableDoseIDs: Set<UUID> = []
        for record in document.doses {
            guard let prescriptionID = record.prescriptionId, filePrescriptionIDs.contains(prescriptionID) else {
                plan.result.doses.skipped += 1
                continue
            }
            reachableDoseIDs.insert(record.id)
            if admit(record.id) {
                plan.doses.append(record)
                plan.result.doses.imported += 1
            } else {
                plan.result.doses.skipped += 1
            }
        }

        for record in document.conditionChecks {
            guard let doseID = record.doseId, reachableDoseIDs.contains(doseID), admit(record.id) else {
                plan.result.conditionChecks.skipped += 1
                continue
            }
            plan.conditionChecks.append(record)
            plan.result.conditionChecks.imported += 1
        }

        for record in document.weightSamples {
            if record.source == "healthKit" {
                plan.result.leftToHealthApp += 1
            } else if admit(record.id) {
                plan.weightSamples.append(record)
                plan.result.weightSamples.imported += 1
            } else {
                plan.result.weightSamples.skipped += 1
            }
        }

        for record in document.strengthSessions {
            if record.source == "healthKit" {
                plan.result.leftToHealthApp += 1
            } else if admit(record.id) {
                plan.strengthSessions.append(record)
                plan.result.strengthSessions.imported += 1
            } else {
                plan.result.strengthSessions.skipped += 1
            }
        }

        for record in document.proteinEntries {
            if admit(record.id) {
                plan.proteinEntries.append(record)
                plan.result.proteinEntries.imported += 1
            } else {
                plan.result.proteinEntries.skipped += 1
            }
        }

        for record in document.habitChecks {
            if admit(record.id) {
                plan.habitChecks.append(record)
                plan.result.habitChecks.imported += 1
            } else {
                plan.result.habitChecks.skipped += 1
            }
        }

        for record in document.clinicQuestions {
            if admit(record.id) {
                plan.clinicQuestions.append(record)
                plan.result.clinicQuestions.imported += 1
            } else {
                plan.result.clinicQuestions.skipped += 1
            }
        }

        return plan
    }
}
