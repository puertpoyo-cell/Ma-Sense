import Foundation
import SwiftData
import UniformTypeIdentifiers

/// 설정 > 데이터: 전체 내보내기·가져오기·전체 삭제 (EXPORT_FORMAT.md). 서버 없이 기기 안에서만 처리한다.
/// 파일 형식과 가져오기 규칙은 `ExportCodec`(Rules), 이 서비스는 SwiftData 읽기·쓰기만 맡는다.
@MainActor
enum ExportService {
    /// "1.0.0 (12)"
    nonisolated static var appVersionWithBuild: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(AppConfig.appVersion) (\(build))"
    }

    /// "1.0.0"
    nonisolated static var schemaVersion: String {
        let version = SchemaV1.versionIdentifier
        return "\(version.major).\(version.minor).\(version.patch)"
    }

    /// 기기 식별자("iPhone16,2")와 OS 버전. 시뮬레이터에서는 흉내 내는 기기 식별자
    nonisolated static var currentDevice: ExportDocument.Device {
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: system.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let systemVersion = os.patchVersion == 0
            ? "\(os.majorVersion).\(os.minorVersion)"
            : "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        return ExportDocument.Device(model: model, systemVersion: systemVersion)
    }

    // MARK: 내보내기

    static func makeDocument(
        context: ModelContext,
        now: Date,
        appVersion: String = ExportService.appVersionWithBuild,
        device: ExportDocument.Device = ExportService.currentDevice
    ) throws -> ExportDocument {
        let settings = try context.fetch(FetchDescriptor<UserSettings>(sortBy: [SortDescriptor(\.createdAt)])).first
        return try ExportDocument(
            appVersion: appVersion,
            schemaVersion: schemaVersion,
            exportedAt: now,
            device: device,
            settings: settings?.exportRecord,
            prescriptions: context.fetch(FetchDescriptor<Prescription>(sortBy: [SortDescriptor(\.startDate)])).map(\.exportRecord),
            doses: context.fetch(FetchDescriptor<Dose>(sortBy: [SortDescriptor(\.administeredAt)])).map(\.exportRecord),
            conditionChecks: ConditionCheck.all(in: context).map(\.exportRecord),
            weightSamples: WeightSample.all(in: context).map(\.exportRecord),
            proteinEntries: context.fetch(FetchDescriptor<ProteinEntry>(sortBy: [SortDescriptor(\.date)])).map(\.exportRecord),
            strengthSessions: context.fetch(FetchDescriptor<StrengthSession>(sortBy: [SortDescriptor(\.startedAt)])).map(\.exportRecord),
            habitChecks: context.fetch(FetchDescriptor<HabitCheck>(sortBy: [SortDescriptor(\.date)])).map(\.exportRecord)
        )
    }

    /// 공유 시트에 넘길 임시 파일. 파일명 `Masense_Export_2026-10-21.masense.json`
    static func writeExportFile(context: ModelContext, now: Date = Date(), calendar: Calendar = .current) throws -> URL {
        let data = try ExportCodec.encode(makeDocument(context: context, now: now), timeZone: calendar.timeZone)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(ExportCodec.fileName(exportedAt: now, calendar: calendar))
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    // MARK: 가져오기

    /// 파일 선택기가 준 URL을 읽고 형식·버전을 확인한다 (규칙 1~3). 저장은 사용자가 방식을 고른 뒤 `apply`
    static func readFile(at url: URL) throws -> ExportDocument {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ExportCodec.ImportError.unreadable
        }
        return try ExportCodec.decode(data)
    }

    /// 규칙 4~7. 교체 모드는 기록을 모두 지운 뒤 넣고(설정 레코드는 남겨 값만 바꾼다), 추가 모드는 같은 ID를 건너뛴다.
    /// 지우기와 넣기를 한 번에 저장한다. 던지면 부르는 쪽이 `context.rollback()`
    static func apply(
        _ document: ExportDocument,
        mode: ExportCodec.ImportMode,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> ExportCodec.ImportResult {
        // 추가 모드에서 파일의 투약·컨디션 체크가 이 기기에 이미 있는 처방·투약에 붙을 수 있게 ID로 찾아 둔다
        var prescriptions: [UUID: Prescription] = [:]
        var doses: [UUID: Dose] = [:]
        var existingIDs: Set<UUID> = []
        switch mode {
        case .replace:
            // 저장은 마지막에 한 번만. 실패하면 부르는 쪽이 rollback해 이 기기의 기록이 그대로 남는다
            try deleteRecords(context: context)
        case .add:
            prescriptions = try uniqueByID(context.fetch(FetchDescriptor<Prescription>()), id: \.id)
            doses = try uniqueByID(context.fetch(FetchDescriptor<Dose>()), id: \.id)
            existingIDs = try Set(prescriptions.keys)
                .union(doses.keys)
                .union(context.fetch(FetchDescriptor<ConditionCheck>()).map(\.id))
                .union(context.fetch(FetchDescriptor<WeightSample>()).map(\.id))
                .union(context.fetch(FetchDescriptor<ProteinEntry>()).map(\.id))
                .union(context.fetch(FetchDescriptor<StrengthSession>()).map(\.id))
                .union(context.fetch(FetchDescriptor<HabitCheck>()).map(\.id))
        }

        let plan = ExportCodec.importPlan(document, mode: mode, existingIDs: existingIDs)

        if let settings = plan.settings {
            try UserSettings.current(in: context).apply(settings)
        }
        for record in plan.prescriptions {
            let prescription = Prescription(record: record)
            context.insert(prescription)
            prescriptions[prescription.id] = prescription
        }
        for record in plan.doses {
            let dose = Dose(record: record)
            context.insert(dose)
            dose.prescription = record.prescriptionId.flatMap { prescriptions[$0] }
            doses[dose.id] = dose
        }
        for record in plan.conditionChecks {
            let check = ConditionCheck(record: record)
            context.insert(check)
            check.dose = record.doseId.flatMap { doses[$0] }
        }
        plan.weightSamples.forEach { context.insert(WeightSample(record: $0)) }
        plan.proteinEntries.forEach { context.insert(ProteinEntry(record: $0)) }
        plan.strengthSessions.forEach { context.insert(StrengthSession(record: $0)) }
        plan.habitChecks.forEach { context.insert(HabitCheck(record: $0)) }

        try resolveActivePrescriptions(context: context, calendar: calendar)
        try context.save()
        return plan.result
    }

    /// 규칙 7. 이 기기의 처방과 가져온 처방을 함께 보고 활성 처방을 하나로 맞춘다
    static func resolveActivePrescriptions(context: ModelContext, calendar: Calendar) throws {
        // 교체 모드에서 지우고 아직 저장하지 않은 처방은 뺀다
        let all = try context.fetch(FetchDescriptor<Prescription>()).filter { !$0.isDeleted }
        let resolved = PrescriptionRules.resolvingActive(all.map(\.span), calendar: calendar)
        for (prescription, span) in zip(all, resolved) {
            prescription.isActive = span.isActive
            prescription.endDate = span.endDate
        }
    }

    private static func uniqueByID<T>(_ items: [T], id: KeyPath<T, UUID>) -> [UUID: T] {
        Dictionary(items.map { ($0[keyPath: id], $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: 삭제

    /// 모든 기록과 설정을 즉시 영구 삭제한다 (COMPLIANCE.md 5).
    static func deleteAll(context: ModelContext) throws {
        try deleteRecords(context: context)
        try context.fetch(FetchDescriptor<UserSettings>()).forEach { context.delete($0) }
        try context.save()
    }

    /// 설정을 뺀 모든 기록. 자식부터 지운다
    private static func deleteRecords(context: ModelContext) throws {
        try context.fetch(FetchDescriptor<ConditionCheck>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Dose>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Prescription>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<WeightSample>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<ProteinEntry>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<StrengthSession>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<HabitCheck>()).forEach { context.delete($0) }
    }
}

extension UTType {
    /// `.masense.json` 내보내기 파일 (Config/Masense-Info.plist `UTExportedTypeDeclarations`).
    /// iOS는 마지막 확장자(json)로 형식을 정하므로 파일 선택기는 `.json`도 함께 받는다
    static let masenseExport = UTType(exportedAs: ExportCodec.typeIdentifier, conformingTo: .json)
}
