import Foundation
import Observation
import SwiftData

/// S8 운동 기록 폼. 저컨디션 날이면 걷기·스트레칭·쉬기가 먼저 (R11). "쉬는 날도 기록".
@Observable
final class StrengthLogModel {
    var kind: SessionKind
    var durationMinutes: Int = 20
    var intensity: Intensity = .moderate
    var startedAt: Date
    var note: String = ""

    let kindOrder: [SessionKind]
    let openedAt: Date

    static let durationRange = 5...180
    static let durationStep = 5

    init(isLowCondition: Bool, now: Date = Date()) {
        kindOrder = StrengthRules.kindOrder(isLowCondition: isLowCondition)
        kind = kindOrder[0]
        openedAt = now
        startedAt = now
    }

    /// 쉬기는 시간·강도를 받지 않는다
    var takesDetails: Bool { kind != .rest }

    @discardableResult
    func save(in context: ModelContext) throws -> StrengthSession {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = StrengthSession(
            startedAt: startedAt,
            durationMinutes: takesDetails ? durationMinutes : 0,
            kind: kind,
            intensity: takesDetails ? intensity : .light,
            source: .manual,
            note: trimmed.isEmpty ? nil : trimmed
        )
        context.insert(session)
        try context.save()
        return session
    }
}
