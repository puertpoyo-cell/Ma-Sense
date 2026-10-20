import Foundation
import SwiftData

// 자주 쓰는 조회. 뷰모델과 서비스가 쓴다.

extension UserSettings {
    /// 단일 레코드. 없으면 만들어서 돌려준다.
    static func current(in context: ModelContext) throws -> UserSettings {
        var descriptor = FetchDescriptor<UserSettings>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let settings = UserSettings()
        context.insert(settings)
        return settings
    }
}

extension Prescription {
    /// 활성 처방. 항상 1개 이하.
    static func active(in context: ModelContext) throws -> Prescription? {
        var descriptor = FetchDescriptor<Prescription>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 새 처방을 활성으로 만들고 이전 처방은 보관한다 (SCREENS.md S9).
    static func activate(_ prescription: Prescription, in context: ModelContext) throws {
        let others = try context.fetch(FetchDescriptor<Prescription>(predicate: #Predicate { $0.isActive }))
        for other in others where other.persistentModelID != prescription.persistentModelID {
            other.isActive = false
        }
        prescription.isActive = true
        if prescription.modelContext == nil {
            context.insert(prescription)
        }
    }
}

extension ConditionCheck {
    static func all(in context: ModelContext) throws -> [ConditionCheck] {
        try context.fetch(FetchDescriptor<ConditionCheck>(sortBy: [SortDescriptor(\.checkedAt)]))
    }
}

extension WeightSample {
    static func all(in context: ModelContext) throws -> [WeightSample] {
        try context.fetch(FetchDescriptor<WeightSample>(sortBy: [SortDescriptor(\.measuredAt)]))
    }
}
