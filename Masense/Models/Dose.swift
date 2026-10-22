import Foundation
import SwiftData

/// 투약 1회 기록 (DATA_MODEL.md). 삭제 대신 `isCancelled`로 취소한다 (리포트 무결성).
/// 부위는 rawValue로 저장하고 `site`로 읽고 쓴다 (CloudKit 호환 규칙 4).
@Model
final class Dose {
    var id: UUID = UUID()
    /// 실제 투약 시각
    var administeredAt: Date = Date.now
    /// 예정일 (마디 기준점)
    var scheduledFor: Date = Date.now
    /// `BodySite` rawValue
    var siteRaw: String = "abdomenUpperLeft"
    /// 처방 내 회차 (1부터)
    var sequence: Int = 1
    /// 자유 메모
    var note: String?
    /// 잘못 기록 취소용. 리포트에서는 제외
    var isCancelled: Bool = false
    var prescription: Prescription?
    @Relationship(deleteRule: .cascade, inverse: \ConditionCheck.dose)
    var conditionChecks: [ConditionCheck] = []
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        administeredAt: Date,
        scheduledFor: Date,
        site: BodySite,
        sequence: Int,
        note: String? = nil,
        isCancelled: Bool = false,
        prescription: Prescription? = nil,
        conditionChecks: [ConditionCheck] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.administeredAt = administeredAt
        self.scheduledFor = scheduledFor
        self.siteRaw = site.rawValue
        self.sequence = sequence
        self.note = note
        self.isCancelled = isCancelled
        self.prescription = prescription
        self.conditionChecks = conditionChecks
        self.createdAt = createdAt
    }

    /// 주사 부위. 모르는 rawValue는 기본 부위로 읽는다
    var site: BodySite {
        get { BodySite(rawValue: siteRaw) ?? .abdomenUpperLeft }
        set { siteRaw = newValue.rawValue }
    }
}
