import Foundation
import SwiftData

/// 처방: 펜 수·회차·다음 진료일 묶음 (DATA_MODEL.md). 활성 처방은 항상 1개.
@Model
final class Prescription {
    @Attribute(.unique) var id: UUID
    /// 처방 시작일
    var startDate: Date
    /// 처방받은 펜 수
    var penCount: Int
    /// 펜당 회차 (기본 4)
    var dosesPerPen: Int
    /// 투약 간격(일). 기본 7, UI는 7만 노출
    var intervalDays: Int
    /// 1(일)~7(토), `Calendar` weekday
    var scheduledWeekday: Int
    /// 예정 시각. `DateComponents` 대신 시·분을 따로 저장한다 (SwiftData 저장 안정성)
    var scheduledHour: Int
    var scheduledMinute: Int
    /// 다음 진료일
    var nextClinicDate: Date?
    /// 사용자가 적는 자유 메모. 앱은 해석하지 않는다 (COMPLIANCE.md 2.2)
    var doseLabel: String?
    /// 현재 처방 여부
    var isActive: Bool
    @Relationship(deleteRule: .cascade, inverse: \Dose.prescription)
    var doses: [Dose]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        startDate: Date,
        penCount: Int,
        dosesPerPen: Int = 4,
        intervalDays: Int = 7,
        scheduledWeekday: Int,
        scheduledHour: Int,
        scheduledMinute: Int = 0,
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
