import Foundation
import SwiftData

/// 처방: 펜 수·회차·다음 진료일 묶음 (DATA_MODEL.md). 활성 처방은 항상 1개 (= `endDate == nil`).
/// CloudKit 호환 규칙: unique 없음, 모든 저장 속성에 기본값 또는 옵셔널.
/// 처방은 지우지 않고 `startDate`/`endDate` 체인으로 쌓는다 (DATA_MODEL.md "처방 이력").
@Model
final class Prescription {
    var id: UUID = UUID()
    /// 처방 시작일
    var startDate: Date = Date.now
    /// 처방받은 펜 수
    var penCount: Int = 1
    /// 펜당 회차
    var dosesPerPen: Int = 4
    /// v1은 항상 7. UI·Rules는 주 1회를 전제로 하며 이 값을 읽지 않는다 (다른 주기를 열 때 스키마 변경을 피하려고 미리 둔 필드)
    var intervalDays: Int = 7
    /// 1(일)~7(토), `Calendar` weekday
    var scheduledWeekday: Int = 5
    /// 예정 시각. `DateComponents` 대신 시·분을 따로 저장한다 (SwiftData·CloudKit 저장 안정성)
    var scheduledHour: Int = 20
    var scheduledMinute: Int = 0
    /// 처방 종료일. 새 처방을 시작하면 이전 처방의 endDate = 새 처방 startDate 전날
    var endDate: Date?
    /// 다음 진료일
    var nextClinicDate: Date?
    /// 사용자가 적는 자유 메모. 앱은 해석하지 않는다 (COMPLIANCE.md 2.2)
    var doseLabel: String?
    /// 현재 처방 여부
    var isActive: Bool = true
    @Relationship(deleteRule: .cascade, inverse: \Dose.prescription)
    var doses: [Dose] = []
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        startDate: Date,
        penCount: Int,
        dosesPerPen: Int = 4,
        intervalDays: Int = 7,
        scheduledWeekday: Int,
        scheduledHour: Int,
        scheduledMinute: Int = 0,
        endDate: Date? = nil,
        nextClinicDate: Date? = nil,
        doseLabel: String? = nil,
        isActive: Bool = true,
        doses: [Dose] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.startDate = startDate
        self.penCount = penCount
        self.dosesPerPen = dosesPerPen
        self.intervalDays = intervalDays
        self.scheduledWeekday = scheduledWeekday
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.endDate = endDate
        self.nextClinicDate = nextClinicDate
        self.doseLabel = doseLabel
        self.isActive = isActive
        self.doses = doses
        self.createdAt = createdAt
    }

    /// 예정 시각 (hour, minute)
    var scheduledTime: DateComponents {
        get { DateComponents(hour: scheduledHour, minute: scheduledMinute) }
        set {
            scheduledHour = newValue.hour ?? 0
            scheduledMinute = newValue.minute ?? 0
        }
    }

    // 파생값. 저장하지 않는다.
    var totalDoses: Int { penCount * dosesPerPen }
    var usedDoses: Int { doses.filter { !$0.isCancelled }.count }
    var remainingDoses: Int { max(totalDoses - usedDoses, 0) }
}
