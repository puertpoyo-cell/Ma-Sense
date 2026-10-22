import Foundation
import SwiftData

/// 단일 레코드 설정 (DATA_MODEL.md). CloudKit 호환 규칙: unique 없음, 모든 저장 속성에 기본값 또는 옵셔널.
@Model
final class UserSettings {
    var id: UUID = UUID()
    /// "처방은 의사, 기록은 마선생" 확인
    var hasAcceptedRoleNotice: Bool = false
    /// 만 19세 이상 확인
    var hasConfirmedAdult: Bool = false
    var reminderEnabled: Bool = true
    /// 미기록 리마인드 시각, 기본 20
    var eveningReminderHour: Int = 20
    var conditionCheckEnabled: Bool = true
    /// 기본 1
    var clinicReminderDaysBefore: Int = 1
    /// 남은 회차가 이 값일 때 진료 예약 알림, 기본 2
    var exhaustionReminderDosesLeft: Int = 2
    /// 사용자/의료진 입력. nil이면 안내만 (M2)
    var proteinTargetGrams: Int?
    /// 1.2~1.6 g/kg 안내 계산용 (M2)
    var bodyWeightForGuideKg: Double?
    var healthKitAuthorized: Bool = false
    /// StoreKit 검증 결과 캐시. 진실 원천은 StoreKit
    var hasPurchasedPro: Bool = false
    /// 기본 "midnight"
    var reportTheme: String = "midnight"
    /// 리포트 기본 기간 (`ReportPeriod.storageValue`). nil이면 자동(R12 기본값)
    var reportDefaultPeriod: String?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        hasAcceptedRoleNotice: Bool = false,
        hasConfirmedAdult: Bool = false,
        reminderEnabled: Bool = true,
        eveningReminderHour: Int = 20,
        conditionCheckEnabled: Bool = true,
        clinicReminderDaysBefore: Int = 1,
        exhaustionReminderDosesLeft: Int = 2,
        proteinTargetGrams: Int? = nil,
        bodyWeightForGuideKg: Double? = nil,
        healthKitAuthorized: Bool = false,
        hasPurchasedPro: Bool = false,
        reportTheme: String = "midnight",
        reportDefaultPeriod: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hasAcceptedRoleNotice = hasAcceptedRoleNotice
        self.hasConfirmedAdult = hasConfirmedAdult
        self.reminderEnabled = reminderEnabled
        self.eveningReminderHour = eveningReminderHour
        self.conditionCheckEnabled = conditionCheckEnabled
        self.clinicReminderDaysBefore = clinicReminderDaysBefore
        self.exhaustionReminderDosesLeft = exhaustionReminderDosesLeft
        self.proteinTargetGrams = proteinTargetGrams
        self.bodyWeightForGuideKg = bodyWeightForGuideKg
        self.healthKitAuthorized = healthKitAuthorized
        self.hasPurchasedPro = hasPurchasedPro
        self.reportTheme = reportTheme
        self.reportDefaultPeriod = reportDefaultPeriod
        self.createdAt = createdAt
    }

    /// 온보딩(S0)을 마쳤는지
    var hasCompletedOnboarding: Bool {
        hasAcceptedRoleNotice && hasConfirmedAdult
    }
}
