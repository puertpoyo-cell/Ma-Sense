import Foundation
import SwiftData

/// 투약 1회 기록 (DATA_MODEL.md). 삭제 대신 `isCancelled`로 취소한다 (리포트 무결성).
/// 부위는 rawValue로 저장하고 `site`로 읽고 쓴다 (CloudKit 호환 규칙 4). 지난 투약 한꺼번에 입력에서 부위를 모르면 `"unknown"` (D6)
@Model
final class Dose {
    var id: UUID = UUID()
    /// 실제 투약 시각
    var administeredAt: Date = Date.now
    /// 예정일 (마디 기준점)
    var scheduledFor: Date = Date.now
    /// `BodySite` rawValue. 부위 기록 없음은 `Dose.unknownSiteRaw`
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
        site: BodySite?,
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
        self.siteRaw = site?.rawValue ?? Dose.unknownSiteRaw
        self.sequence = sequence
        self.note = note
        self.isCancelled = isCancelled
        self.prescription = prescription
        self.conditionChecks = conditionChecks
        self.createdAt = createdAt
    }

    /// 부위를 모르고 저장한 기록 (D6 지난 투약 한꺼번에 입력)
    static let unknownSiteRaw = "unknown"

    /// 주사 부위. `"unknown"`이나 모르는 rawValue(나중 버전이 더한 값 등)는 nil = 부위 기록 없음
    var site: BodySite? {
        get { BodySite(rawValue: siteRaw) }
        set { siteRaw = newValue?.rawValue ?? Dose.unknownSiteRaw }
    }
}
