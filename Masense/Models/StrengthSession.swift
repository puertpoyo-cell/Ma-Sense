import Foundation
import SwiftData

/// 근력운동 마디 (DATA_MODEL.md, M2). `.rest`는 "쉬는 날도 기록"을 위해 있다.
/// 리포트의 근력운동 횟수에는 `.strength`만 센다.
@Model
final class StrengthSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var durationMinutes: Int
    var kind: SessionKind
    var intensity: Intensity
    var source: SessionSource
    var healthKitUUID: UUID?
    var note: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        startedAt: Date,
        durationMinutes: Int,
        kind: SessionKind,
        intensity: Intensity = .moderate,
        source: SessionSource = .manual,
        healthKitUUID: UUID? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.kind = kind
        self.intensity = intensity
        self.source = source
        self.healthKitUUID = healthKitUUID
        self.note = note
        self.createdAt = createdAt
    }
}
