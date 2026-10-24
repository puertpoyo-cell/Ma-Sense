import Foundation
import SwiftData

/// 근력운동 마디 (DATA_MODEL.md, M2). `.rest`는 "쉬는 날도 기록"을 위해 있다.
/// 리포트의 근력운동 횟수에는 `.strength`만 센다.
@Model
final class StrengthSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var durationMinutes: Int = 0
    /// `SessionKind` rawValue
    var kindRaw: String = "strength"
    /// `Intensity` rawValue
    var intensityRaw: String = "moderate"
    /// `SessionSource` rawValue
    var sourceRaw: String = "manual"
    var healthKitUUID: UUID?
    var note: String?
    var createdAt: Date = Date.now

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
        self.kindRaw = kind.rawValue
        self.intensityRaw = intensity.rawValue
        self.sourceRaw = source.rawValue
        self.healthKitUUID = healthKitUUID
        self.note = note
        self.createdAt = createdAt
    }

    var kind: SessionKind {
        get { SessionKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    var intensity: Intensity {
        get { Intensity(rawValue: intensityRaw) ?? .moderate }
        set { intensityRaw = newValue.rawValue }
    }

    var source: SessionSource {
        get { SessionSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
