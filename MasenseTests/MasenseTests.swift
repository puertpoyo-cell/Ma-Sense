import SwiftData
import Testing

@testable import Masense

// M0 더미 테스트. 스키마가 열리는지와 디자인 토큰이 문서 값과 같은지만 확인한다.
struct MasenseSmokeTests {
    @Test func currentSchemaOpensInMemory() throws {
        let container = try ModelContainer.masense(inMemory: true)
        let modelNames = Set(container.schema.entities.map(\.name))
        #expect(modelNames == [
            "Prescription", "Dose", "ConditionCheck", "WeightSample", "UserSettings",
            "ProteinEntry", "StrengthSession", "HabitCheck", "ClinicQuestion",
            "ClinicVisit", "LabResult", "ClinicPhoto", "PenSupply",
        ])
    }

    @Test func spacingTokensFollowFourPointGrid() {
        #expect(Spacing.s1 == 4)
        #expect(Spacing.s5 == 24)
        #expect(Spacing.s7 == 48)
        #expect(Radius.card == 20)
    }

    @Test func prescriptionDerivedValues() {
        let prescription = Prescription(
            startDate: .now,
            penCount: 3,
            dosesPerPen: 4,
            scheduledWeekday: 5,
            scheduledHour: 20
        )
        #expect(prescription.totalDoses == 12)
        #expect(prescription.remainingDoses == 12)
        #expect(prescription.scheduledTime.hour == 20)
        #expect(prescription.scheduledTime.minute == 0)
    }

    @Test func bodySiteGroups() {
        #expect(BodySite.abdomenLowerRight.group == .abdomen)
        #expect(BodySite.thighLeft.group == .thigh)
        #expect(BodySite.upperArmRight.group == .upperArm)
        #expect(BodySite.allCases.count == 8)
    }

    @Test func symptomSeverityIsClamped() {
        #expect(SymptomEntry(symptom: .nausea, severity: 9).severity == 3)
        #expect(SymptomEntry(symptom: .nausea, severity: -1).severity == 0)
    }
}

// D40 의견 메일: 받는 주소·제목에 버전, 본문에 기기
struct FeedbackMailTests {
    @Test func feedbackMailHasAddressVersionAndDevice() throws {
        let url = try #require(AppConfig.feedbackMailURL(device: "iPhone", systemVersion: "27.1"))
        #expect(url.scheme == "mailto")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == AppConfig.feedbackEmail)
        let subject = components.queryItems?.first { $0.name == "subject" }?.value ?? ""
        let body = components.queryItems?.first { $0.name == "body" }?.value ?? ""
        #expect(subject.contains(AppConfig.appVersionWithBuild))
        #expect(body.contains("iPhone") && body.contains("27.1"))
    }
}
