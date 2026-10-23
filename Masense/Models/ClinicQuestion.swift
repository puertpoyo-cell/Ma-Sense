import Foundation
import SwiftData

/// 진료 때 물어볼 것 (DATA_MODEL.md, D6). 사용자가 적은 문장을 그대로 두고 앱은 해석하지 않는다.
/// 아직 묻지 않은 것만 리포트에 실린다. 관계 없음 (SchemaV3에서 모델만 추가해 경량 이전)
@Model
final class ClinicQuestion {
    var id: UUID = UUID()
    var text: String = ""
    /// 진료에서 물어봤다고 표시한 시각. nil이면 아직 묻지 않음
    var askedAt: Date?
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), text: String, askedAt: Date? = nil, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.askedAt = askedAt
        self.createdAt = createdAt
    }
}
