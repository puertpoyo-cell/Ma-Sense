import Foundation
import SwiftData

/// 진료 직후 기록 (DATA_MODEL.md, D20). 진료일, 사용자가 적은 메모(의사에게 들은 것 등), 검사 결과와 검사지 사진.
/// 앱은 메모·수치를 해석하지 않는다 (COMPLIANCE.md 2.2 검사 결과)
@Model
final class ClinicVisit {
    var id: UUID = UUID()
    var visitedAt: Date = Date.now
    /// 자유 메모. 해석하지 않는다
    var note: String?
    @Relationship(deleteRule: .cascade, inverse: \LabResult.visit)
    var labResults: [LabResult]? = []
    @Relationship(deleteRule: .cascade, inverse: \ClinicPhoto.visit)
    var photos: [ClinicPhoto]? = []
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), visitedAt: Date, note: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.visitedAt = visitedAt
        self.note = note
        self.createdAt = createdAt
    }
}

/// 검사 결과 한 항목 (D20). 숫자·단위만 저장하고 정상/높음 같은 판단은 하지 않는다
@Model
final class LabResult {
    var id: UUID = UUID()
    var measuredAt: Date = Date.now
    /// `LabItem` rawValue. 목록에 없는 항목은 `"custom"`이고 이름은 `customName`
    var itemRaw: String = "custom"
    var customName: String?
    var value: Double = 0
    var unit: String = ""
    /// 사용자가 검사지에서 옮겨 적은 기준 범위 등. 해석하지 않는다
    var note: String?
    var visit: ClinicVisit?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        measuredAt: Date,
        item: LabItem,
        customName: String? = nil,
        value: Double,
        unit: String,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.itemRaw = item.rawValue
        self.customName = customName
        self.value = value
        self.unit = unit
        self.note = note
        self.createdAt = createdAt
    }

    /// 모르는 rawValue는 `.custom`
    var item: LabItem {
        get { LabItem(rawValue: itemRaw) ?? .custom }
        set { itemRaw = newValue.rawValue }
    }
}

/// 검사지 사진 (D20). 원본 확인용으로 기기 안에만 둔다. 내보내기 파일에는 담지 않는다
@Model
final class ClinicPhoto {
    var id: UUID = UUID()
    @Attribute(.externalStorage)
    var imageData: Data?
    var visit: ClinicVisit?
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), imageData: Data?, createdAt: Date = Date()) {
        self.id = id
        self.imageData = imageData
        self.createdAt = createdAt
    }
}
