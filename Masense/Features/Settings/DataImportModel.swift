import Foundation
import Observation
import SwiftData

/// 설정 > 데이터 > 기록 가져오기 (EXPORT_FORMAT.md 가져오기 규칙 4·9).
/// 파일 확인 → 방식 고르기(기본 교체) → 한 번 더 확인 → 결과. 규칙 자체는 `ExportCodec`·`ExportService`에 있다.
@MainActor
@Observable
final class DataImportModel {
    /// 결과 화면의 한 줄. `titleKey`는 Localizable 키
    struct Row: Equatable {
        let titleKey: String
        let count: ExportCodec.ImportResult.Count
    }

    let document: ExportDocument
    var mode: ExportCodec.ImportMode = .replace
    var confirms = false
    var savingFailed = false
    private(set) var result: ExportCodec.ImportResult?

    init(document: ExportDocument, result: ExportCodec.ImportResult? = nil) {
        self.document = document
        self.result = result
    }

    var fileRows: [Row] { Self.fileRows(document) }

    var resultRows: [Row] { result.map(Self.resultRows) ?? [] }

    /// 기록을 저장한다. 알림 재등록·건강 앱 재동기화(규칙 8)는 화면이 이어서 한다
    func importRecords(context: ModelContext, calendar: Calendar) {
        do {
            result = try ExportService.apply(document, mode: mode, context: context, calendar: calendar)
        } catch {
            context.rollback()
            savingFailed = true
        }
    }

    /// 파일에 담긴 레코드 수. 비어 있는 종류는 뺀다
    static func fileRows(_ document: ExportDocument) -> [Row] {
        let counts: [(String, Int)] = [
            ("import.kind.prescriptions", document.prescriptions.count),
            ("import.kind.doses", document.doses.count),
            ("import.kind.conditionChecks", document.conditionChecks.count),
            ("import.kind.weightSamples", document.weightSamples.count),
            ("import.kind.proteinEntries", document.proteinEntries.count),
            ("import.kind.strengthSessions", document.strengthSessions.count),
            ("import.kind.habitChecks", document.habitChecks.count),
            ("import.kind.clinicQuestions", document.clinicQuestions.count),
        ]
        return counts
            .filter { $0.1 > 0 }
            .map { Row(titleKey: $0.0, count: ExportCodec.ImportResult.Count(imported: $0.1)) }
    }

    /// 가져온 수·건너뛴 수. 둘 다 0인 종류는 뺀다
    static func resultRows(_ result: ExportCodec.ImportResult) -> [Row] {
        [
            Row(titleKey: "import.kind.prescriptions", count: result.prescriptions),
            Row(titleKey: "import.kind.doses", count: result.doses),
            Row(titleKey: "import.kind.conditionChecks", count: result.conditionChecks),
            Row(titleKey: "import.kind.weightSamples", count: result.weightSamples),
            Row(titleKey: "import.kind.proteinEntries", count: result.proteinEntries),
            Row(titleKey: "import.kind.strengthSessions", count: result.strengthSessions),
            Row(titleKey: "import.kind.habitChecks", count: result.habitChecks),
            Row(titleKey: "import.kind.clinicQuestions", count: result.clinicQuestions),
        ]
        .filter { $0.count.imported > 0 || $0.count.skipped > 0 }
    }
}
