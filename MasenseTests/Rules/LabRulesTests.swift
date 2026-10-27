import Foundation
import Testing

@testable import Masense

// D20 검사지 글자에서 항목·값 찾기, 항목별 최근 값
struct LabRulesTests {
    @Test func readsValuesAfterNamesAndIgnoresRanges() {
        let lines = [
            "검사항목 결과 단위 참고치",
            "당화혈색소(HbA1c) 5.8 % 4.0-6.0",
            "공복혈당 98 mg/dL 70-100",
            "총콜레스테롤 182 mg/dL",
            "HDL 콜레스테롤 52 mg/dL",
            "LDL 콜레스테롤 110 mg/dL",
            "중성지방 140 mg/dL",
            "AST(SGOT) 24 U/L",
            "ALT(SGPT) 31 U/L",
            "혈색소 13.9 g/dL",
            "비타민D(25-OH) 28.3 ng/mL",
        ]
        let found = LabRules.candidates(lines: lines)
        let byItem = Dictionary(uniqueKeysWithValues: found.map { ($0.item, $0) })
        #expect(byItem[.hba1c]?.value == 5.8)
        #expect(byItem[.hba1c]?.unit == "%")
        #expect(byItem[.fastingGlucose]?.value == 98)
        #expect(byItem[.totalCholesterol]?.value == 182)
        #expect(byItem[.hdl]?.value == 52)
        #expect(byItem[.ldl]?.value == 110)
        #expect(byItem[.triglycerides]?.value == 140)
        #expect(byItem[.ast]?.value == 24)
        #expect(byItem[.alt]?.value == 31)
        #expect(byItem[.hemoglobin]?.value == 13.9)
        #expect(byItem[.vitaminD]?.value == 28.3)
        // 머리줄을 뺀 10줄이 10개 항목
        #expect(found.count == 10)
    }

    @Test func englishShortNamesNeedWordBoundaries() {
        // Hb는 HbA1c 안에서 혈색소로 잡히지 않는다
        let found = LabRules.candidates(lines: ["HbA1c 6.1 %", "Hb 12.8 g/dL"])
        #expect(found.first { $0.item == .hba1c }?.value == 6.1)
        #expect(found.first { $0.item == .hemoglobin }?.value == 12.8)
        // "Crab" 같은 단어는 크레아티닌이 아니다
        #expect(LabRules.candidates(lines: ["Crab 3"]).isEmpty)
    }

    @Test func valueOnNextLineWhenTableIsSplit() {
        let found = LabRules.candidates(lines: ["eGFR", "95", "TSH", "2.1 uIU/mL"])
        #expect(found.first { $0.item == .egfr }?.value == 95)
        #expect(found.first { $0.item == .egfr }?.unit == "mL/min/1.73m²")
        #expect(found.first { $0.item == .tsh }?.value == 2.1)
        // 이름만 있고 숫자가 없으면 후보가 없다
        #expect(LabRules.candidates(lines: ["페리틴", "참고"]).isEmpty)
    }

    @Test func latestByItemKeepsNewestPerItem() {
        func r(_ day: Int, _ item: LabItem, _ value: Double, name: String? = nil) -> LabResultSnapshot {
            LabResultSnapshot(id: UUID(), measuredAt: TestCalendar.date(2026, 10, day), item: item, customName: name, value: value, unit: item.defaultUnit)
        }
        let results = [r(1, .hba1c, 6.2), r(20, .hba1c, 5.9), r(20, .ldl, 120), r(5, .custom, 3, name: "요산"), r(6, .custom, 4, name: "요산 ")]
        let latest = LabRules.latestByItem(results)
        #expect(latest.count == 3)
        #expect(latest.first { $0.item == .hba1c }?.value == 5.9)
        #expect(latest.first { $0.item == .custom }?.value == 4)
        #expect(LabRules.latestByItem(results, limit: 2).count == 2)
        #expect(LabRules.history(of: "hba1c", in: results).map(\.value) == [6.2, 5.9])
    }

    @Test func boxesOnTheSameRowJoinLeftToRight() {
        let boxes = [
            TextBox(text: "5.8", minX: 0.5, midY: 0.301, height: 0.02),
            TextBox(text: "HbA1c", minX: 0.1, midY: 0.30, height: 0.02),
            TextBox(text: "공복혈당", minX: 0.1, midY: 0.34, height: 0.02),
            TextBox(text: "98", minX: 0.5, midY: 0.339, height: 0.02),
        ]
        #expect(LabRules.lines(from: boxes) == ["HbA1c 5.8", "공복혈당 98"])
        #expect(LabRules.candidates(lines: LabRules.lines(from: boxes)).map(\.value) == [5.8, 98])
    }
}
