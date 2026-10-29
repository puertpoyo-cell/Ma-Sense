import Foundation

/// 검사 결과 항목 (D20). 자주 보는 항목만 목록으로 두고 나머지는 `custom` + 이름 직접 입력.
/// 앱은 숫자만 다룬다. 기준 범위·정상/높음 판단·색은 없다 (COMPLIANCE.md 2.2)
enum LabItem: String, Codable, CaseIterable, Identifiable {
    case hba1c, fastingGlucose
    case totalCholesterol, ldl, hdl, triglycerides
    case ast, alt, ggt
    case creatinine, egfr
    case hemoglobin, ferritin, vitaminD, tsh
    case custom

    var id: String { rawValue }

    /// 검사지에 흔히 쓰는 단위. 사용자가 바꿀 수 있다
    var defaultUnit: String {
        switch self {
        case .hba1c: return "%"
        case .fastingGlucose, .totalCholesterol, .ldl, .hdl, .triglycerides, .creatinine: return "mg/dL"
        case .ast, .alt, .ggt: return "U/L"
        case .egfr: return "mL/min/1.73m²"
        case .hemoglobin: return "g/dL"
        case .ferritin, .vitaminD: return "ng/mL"
        case .tsh: return "μIU/mL"
        case .custom: return ""
        }
    }

    /// 검사지 글자에서 찾을 이름들. 앞에 둔 항목부터 맞춰 본다 (당화혈색소를 혈색소보다, LDL·HDL을 총콜레스테롤보다 먼저)
    var aliases: [String] {
        switch self {
        case .hba1c: return ["당화혈색소", "HbA1c", "Hb A1c", "A1c"]
        case .fastingGlucose: return ["공복혈당", "공복 혈당", "Glucose", "FBS", "FPG", "GLU", "혈당"]
        case .ldl: return ["LDL-C", "LDL"]
        case .hdl: return ["HDL-C", "HDL"]
        case .triglycerides: return ["중성지방", "Triglyceride", "TRIG", "TG"]
        case .totalCholesterol: return ["총콜레스테롤", "총 콜레스테롤", "Total Cholesterol", "T-Chol", "T.Chol", "T-CHOL", "CHOL", "Cholesterol", "TC"]
        case .ast: return ["AST", "SGOT", "GOT"]
        case .alt: return ["ALT", "SGPT", "GPT"]
        case .ggt: return ["감마지티피", "γ-GTP", "γ-GT", "r-GTP", "GGT", "GGTP"]
        case .egfr: return ["eGFR", "사구체여과율"]
        case .creatinine: return ["크레아티닌", "Creatinine", "CREA", "CRE", "Cr"]
        case .hemoglobin: return ["혈색소", "Hemoglobin", "HGB", "Hgb", "Hb"]
        case .ferritin: return ["페리틴", "Ferritin"]
        case .vitaminD: return ["비타민D", "비타민 D", "Vitamin D", "Vit D", "Vit.D", "25(OH)D", "25-OH"]
        case .tsh: return ["갑상선자극호르몬", "TSH"]
        case .custom: return []
        }
    }

    /// 글자 맞추기 순서
    static let matchOrder: [LabItem] = [
        .hba1c, .fastingGlucose, .ldl, .hdl, .triglycerides, .totalCholesterol,
        .ast, .alt, .ggt, .egfr, .creatinine, .hemoglobin, .ferritin, .vitaminD, .tsh,
    ]
}

/// 검사 결과 한 줄 (Rules용 값)
struct LabResultSnapshot: Equatable {
    let id: UUID
    let measuredAt: Date
    let item: LabItem
    let customName: String?
    let value: Double
    let unit: String

    /// 같은 항목인지 가르는 키. 직접 입력 항목은 이름으로
    var itemKey: String {
        item == .custom ? "custom." + (customName ?? "").trimmingCharacters(in: .whitespaces).lowercased() : item.rawValue
    }
}

/// 글자 인식 결과 한 조각. 좌표는 0~1, 위쪽이 0
struct TextBox: Equatable {
    var text: String
    var minX: Double
    var midY: Double
    var height: Double
}

/// 검사지 글자에서 찾은 후보. 사용자가 확인·수정한 뒤에만 저장한다
struct LabCandidate: Equatable {
    var item: LabItem
    var value: Double
    var unit: String
}

enum LabRules {
    /// 검사지 사진에서 읽은 줄들로 후보를 만든다 (D20). 항목마다 처음 찾은 것 하나.
    /// - 이름 뒤 첫 숫자를 값으로 본다 (그 뒤의 기준 범위 숫자는 쓰지 않는다)
    /// - 이름만 있고 숫자가 없으면 다음 줄이 숫자로 시작할 때 그 숫자 (표가 칸별로 읽힌 경우)
    /// - 단위는 줄에 알려진 단위가 있으면 그것, 없으면 항목 기본 단위
    static func candidates(lines: [String]) -> [LabCandidate] {
        var found: [LabCandidate] = []
        var seen: Set<LabItem> = []
        for (index, line) in lines.enumerated() {
            guard let (item, end) = match(line), !seen.contains(item) else { continue }
            // 이름 바로 뒤 괄호 안(예: "비타민D(25-OH)")의 숫자는 값이 아니다. 단위 글자(eGFR의 "1.73")도 값이 아니다 (N-C1)
            let rest = stripUnits(String(line[end...]).replacingOccurrences(of: #"^\s*\([^)]*\)"#, with: "", options: .regularExpression))
            var value = firstNumber(in: rest)
            if value == nil, lines.indices.contains(index + 1) {
                let next = lines[index + 1].trimmingCharacters(in: .whitespaces)
                if let number = firstNumber(in: stripUnits(next)), next.first.map({ $0.isNumber || $0 == "." }) == true {
                    value = number
                }
            }
            guard let value else { continue }
            seen.insert(item)
            found.append(LabCandidate(item: item, value: value, unit: unit(in: line) ?? item.defaultUnit))
        }
        return found
    }

    /// 글자 조각을 줄로 묶는다. 세로 가운데가 글자 높이의 절반 안이면 같은 줄로 보고 왼쪽부터 잇는다
    /// (검사지 표는 항목·결과·단위·참고치가 따로 읽히므로 한 줄로 이어야 이름 뒤 숫자를 찾을 수 있다)
    static func lines(from boxes: [TextBox]) -> [String] {
        var rows: [[TextBox]] = []
        for box in boxes.sorted(by: { $0.midY < $1.midY }) {
            if let last = rows.last, let anchor = last.first,
               abs(anchor.midY - box.midY) <= max(anchor.height, box.height) * 0.5 {
                rows[rows.count - 1].append(box)
            } else {
                rows.append([box])
            }
        }
        return rows.map { row in
            row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " ")
        }
    }

    /// 항목별 가장 최근 값, 최근 검사일 순 (리포트 "최근 검사", 진료 탭)
    static func latestByItem(_ results: [LabResultSnapshot], limit: Int? = nil) -> [LabResultSnapshot] {
        var latest: [String: LabResultSnapshot] = [:]
        for result in results {
            if let current = latest[result.itemKey], current.measuredAt >= result.measuredAt { continue }
            latest[result.itemKey] = result
        }
        let order = Dictionary(uniqueKeysWithValues: LabItem.allCases.enumerated().map { ($1, $0) })
        let sorted = latest.values.sorted {
            if $0.measuredAt != $1.measuredAt { return $0.measuredAt > $1.measuredAt }
            return (order[$0.item] ?? 0, $0.itemKey) < (order[$1.item] ?? 0, $1.itemKey)
        }
        return limit.map { Array(sorted.prefix($0)) } ?? sorted
    }

    /// 한 항목의 기록, 오래된 것부터 (진료 탭 항목 추이)
    static func history(of itemKey: String, in results: [LabResultSnapshot]) -> [LabResultSnapshot] {
        results.filter { $0.itemKey == itemKey }.sorted { $0.measuredAt < $1.measuredAt }
    }

    // MARK: 글자 맞추기

    private static let knownUnits = ["mL/min/1.73", "mg/dL", "g/dL", "ng/mL", "μIU/mL", "uIU/mL", "mIU/L", "U/L", "IU/L", "mmol/L", "%"]

    /// 줄에서 처음 맞는 항목과 이름이 끝나는 위치
    private static func match(_ line: String) -> (LabItem, String.Index)? {
        for item in LabItem.matchOrder {
            for alias in item.aliases {
                if let range = find(alias, in: line) { return (item, range.upperBound) }
            }
        }
        return nil
    }

    /// 영문 이름은 대소문자 무시, 앞뒤가 영문자·숫자가 아닐 때만 (Hb가 HbA1c에, Cr이 Creatinine 밖 단어에 걸리지 않게)
    private static func find(_ alias: String, in line: String) -> Range<String.Index>? {
        var searchStart = line.startIndex
        while let range = line.range(of: alias, options: [.caseInsensitive], range: searchStart..<line.endIndex) {
            let before = range.lowerBound > line.startIndex ? line[line.index(before: range.lowerBound)] : nil
            let after = range.upperBound < line.endIndex ? line[range.upperBound] : nil
            let isASCIIName = alias.unicodeScalars.allSatisfy { $0.isASCII }
            let blocked: (Character?) -> Bool = { c in
                guard isASCIIName, let c else { return false }
                return c.isASCII && (c.isLetter || c.isNumber)
            }
            if !blocked(before), !blocked(after) { return range }
            searchStart = range.upperBound
        }
        return nil
    }

    /// 첫 숫자. 소수점이 쉼표인 검사지("5,8")도 받는다 (N-C1). 천 단위 쉼표("1,234")는 1234
    private static func firstNumber(in text: String) -> Double? {
        guard let range = text.range(of: #"\d+(?:[.,]\d+)?"#, options: .regularExpression) else { return nil }
        var token = String(text[range])
        if let comma = token.firstIndex(of: ",") {
            let decimals = token.distance(from: token.index(after: comma), to: token.endIndex)
            token = decimals == 3 ? token.replacingOccurrences(of: ",", with: "") : token.replacingOccurrences(of: ",", with: ".")
        }
        return Double(token)
    }

    /// 줄에서 알려진 단위 글자를 지운다 (단위 안의 숫자를 값으로 읽지 않게)
    private static func stripUnits(_ text: String) -> String {
        var result = text
        for unit in knownUnits + ["m²", "m2"] {
            result = result.replacingOccurrences(of: unit, with: " ", options: .caseInsensitive)
        }
        return result
    }

    private static func unit(in line: String) -> String? {
        for unit in knownUnits where line.range(of: unit, options: .caseInsensitive) != nil {
            if unit == "mL/min/1.73" { return LabItem.egfr.defaultUnit }
            if unit == "uIU/mL" { return LabItem.tsh.defaultUnit }
            return unit
        }
        return nil
    }
}
