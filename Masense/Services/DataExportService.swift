import Foundation
import SwiftData

/// 설정 > 데이터: 전체 내보내기(JSON)와 전체 삭제. 서버 없이 기기 안에서만 처리한다.
@MainActor
enum DataExportService {
    struct Export: Codable, Equatable {
        let exportedAt: Date
        let appVersion: String
        let prescriptions: [PrescriptionRecord]
        let weights: [WeightRecord]
    }

    struct PrescriptionRecord: Codable, Equatable {
        let id: UUID
        let startDate: Date
        let penCount: Int
        let dosesPerPen: Int
        let intervalDays: Int
        let scheduledWeekday: Int
        let scheduledHour: Int
        let scheduledMinute: Int
        let nextClinicDate: Date?
        let memo: String?
        let isActive: Bool
        let doses: [DoseRecord]
    }

    struct DoseRecord: Codable, Equatable {
        let id: UUID
        let administeredAt: Date
        let scheduledFor: Date
        let site: BodySite
        let sequence: Int
        let note: String?
        let isCancelled: Bool
        let conditionChecks: [ConditionRecord]
    }

    struct ConditionRecord: Codable, Equatable {
        let id: UUID
        let checkedAt: Date
        let window: ConditionWindow
        let symptoms: [SymptomEntry]
        let appetite: AppetiteLevel
        let note: String?
    }

    struct WeightRecord: Codable, Equatable {
        let id: UUID
        let measuredAt: Date
        let kilograms: Double
        let source: WeightSource
        let leanBodyMassKg: Double?
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static func makeExport(context: ModelContext, now: Date) throws -> Export {
        let prescriptions = try context.fetch(FetchDescriptor<Prescription>(sortBy: [SortDescriptor(\.startDate)]))
        let weights = try WeightSample.all(in: context)
        return Export(
            exportedAt: now,
            appVersion: appVersion,
            prescriptions: prescriptions.map { p in
                PrescriptionRecord(
                    id: p.id,
                    startDate: p.startDate,
                    penCount: p.penCount,
                    dosesPerPen: p.dosesPerPen,
                    intervalDays: p.intervalDays,
                    scheduledWeekday: p.scheduledWeekday,
                    scheduledHour: p.scheduledHour,
                    scheduledMinute: p.scheduledMinute,
                    nextClinicDate: p.nextClinicDate,
                    memo: p.doseLabel,
                    isActive: p.isActive,
                    doses: p.doses.sorted { $0.administeredAt < $1.administeredAt }.map { d in
                        DoseRecord(
                            id: d.id,
                            administeredAt: d.administeredAt,
                            scheduledFor: d.scheduledFor,
                            site: d.site,
                            sequence: d.sequence,
                            note: d.note,
                            isCancelled: d.isCancelled,
                            conditionChecks: d.conditionChecks.sorted { $0.checkedAt < $1.checkedAt }.map { c in
                                ConditionRecord(
                                    id: c.id,
                                    checkedAt: c.checkedAt,
                                    window: c.window,
                                    symptoms: c.symptoms,
                                    appetite: c.appetite,
                                    note: c.note
                                )
                            }
                        )
                    }
                )
            },
            weights: weights.map { w in
                WeightRecord(id: w.id, measuredAt: w.measuredAt, kilograms: w.kilograms, source: w.source, leanBodyMassKg: w.leanBodyMassKg)
            }
        )
    }

    static func encode(_ export: Export) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    static func decode(_ data: Data) throws -> Export {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Export.self, from: data)
    }

    /// 공유 시트에 넘길 임시 파일. 파일명 `Masense_Export_2026-10-21.json`
    static func writeExportFile(context: ModelContext, now: Date = Date(), calendar: Calendar = .current) throws -> URL {
        let data = try encode(makeExport(context: context, now: now))
        let day = calendar.dateComponents([.year, .month, .day], from: now)
        let name = String(format: "Masense_Export_%04d-%02d-%02d.json", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// 모든 기록과 설정을 즉시 영구 삭제한다 (COMPLIANCE.md 5). 자식부터 지운다.
    static func deleteAll(context: ModelContext) throws {
        try context.fetch(FetchDescriptor<ConditionCheck>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Dose>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Prescription>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<WeightSample>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<UserSettings>()).forEach { context.delete($0) }
        try context.save()
    }
}
