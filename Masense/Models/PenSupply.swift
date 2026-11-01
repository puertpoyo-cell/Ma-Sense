import Foundation
import SwiftData

/// 받은 펜 기록 (D28, 2026-11-01 사람 요청 "진료 결과에 몇 개 받았는지, 기록 아카이빙에서도 잘 보이게").
/// 진료 기록에서 적거나(그 진료 id), 오늘 화면 "새 펜 받음"에서 적는다(진료 없이).
/// `prescriptionMemo`는 사용자가 적은 글자 그대로(처방 메모와 같은 성격). 앱은 해석·비교·계산하지 않는다 (COMPLIANCE.md)
/// 진료 기록과 관계 대신 id만 들고 있어 기존 모델을 바꾸지 않는다 (CloudKit 운영 스키마는 추가만)
@Model
final class PenSupply {
    var id: UUID = UUID()
    var receivedAt: Date = Date.now
    /// 받은 패키지 수 (1회용 펜은 패키지당 4개, 여러 회 펜은 펜 1개)
    var packages: Int = 1
    /// 적은 그대로. 해석하지 않는다
    var prescriptionMemo: String?
    /// 진료 기록에서 적었으면 그 진료 id
    var visitID: UUID?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        receivedAt: Date,
        packages: Int,
        prescriptionMemo: String? = nil,
        visitID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.receivedAt = receivedAt
        self.packages = packages
        self.prescriptionMemo = prescriptionMemo
        self.visitID = visitID
        self.createdAt = createdAt
    }
}
