import Foundation
import SwiftData
import Testing

@testable import Masense

// 설정 > 데이터 > 기록 가져오기 화면 (EXPORT_FORMAT.md 가져오기 규칙 4·9)
@MainActor
struct DataImportModelTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    @Test func fileRowsCountEachKindInFile() throws {
        var document = try ExportFixture.document()
        document.habitChecks = []
        let rows = DataImportModel.fileRows(document)
        #expect(rows.map(\.titleKey) == [
            "import.kind.prescriptions", "import.kind.doses", "import.kind.conditionChecks",
            "import.kind.weightSamples", "import.kind.proteinEntries", "import.kind.strengthSessions",
        ])
        #expect(rows.map(\.count.imported) == [2, 3, 1, 2, 1, 2])
    }

    @Test func defaultsToReplaceAndShowsResultAfterImport() throws {
        let model = DataImportModel(document: try ExportFixture.document())
        #expect(model.mode == .replace)
        #expect(model.result == nil)

        model.importRecords(context: container.mainContext, calendar: TestCalendar.seoul)

        #expect(model.savingFailed == false)
        #expect(model.result?.leftToHealthApp == 2)
        // 건강 앱 체중 1건은 가져오지 않아 체중은 1건. 모든 종류가 1건 이상이라 7줄
        let weightRow = model.resultRows.first(where: { $0.titleKey == "import.kind.weightSamples" })
        #expect(weightRow?.count == ExportCodec.ImportResult.Count(imported: 1, skipped: 0))
        #expect(model.resultRows.count == 7)
    }

    @Test func resultRowsHideKindsWithNothingToReport() {
        var result = ExportCodec.ImportResult()
        result.doses = ExportCodec.ImportResult.Count(imported: 0, skipped: 2)
        result.weightSamples = ExportCodec.ImportResult.Count(imported: 3, skipped: 0)
        #expect(DataImportModel.resultRows(result).map(\.titleKey) == ["import.kind.doses", "import.kind.weightSamples"])
        #expect(DataImportModel.resultRows(ExportCodec.ImportResult()).isEmpty)
    }
}
