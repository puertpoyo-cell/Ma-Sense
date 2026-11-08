import Foundation
import Observation
import SwiftData

/// D46 기록 직후 되돌리기 (PROPOSAL_U1 B1, 2026-11-08 사람 결정 "0.6에 넣기").
/// 기록 시트가 새 기록을 넣으면 여기에 남기고, "기록했습니다" 토스트가 몇 초 동안 "되돌리기"를 보인다.
/// 되돌리면 방금 넣은 그 기록만 지운다 (방금 만든 것이라 리포트 무결성 규칙의 취소 대신 삭제)
@Observable
final class RecordUndo {
    static let shared = RecordUndo()

    /// 이 시간 안에 토스트가 뜨면 되돌리기를 보인다
    static let window: TimeInterval = 5

    private(set) var lastID: PersistentIdentifier?
    private(set) var registeredAt: Date?

    func register(_ model: any PersistentModel, now: Date = .now) {
        lastID = model.persistentModelID
        registeredAt = now
    }

    func canUndo(now: Date = .now) -> Bool {
        guard lastID != nil, let registeredAt else { return false }
        return now.timeIntervalSince(registeredAt) <= Self.window
    }

    /// 방금 넣은 기록을 지운다. 지웠으면 true
    @discardableResult
    func undo(in context: ModelContext) -> Bool {
        defer { clear() }
        guard let lastID else { return false }
        let model = context.model(for: lastID)
        context.delete(model)
        try? context.save()
        return true
    }

    func clear() {
        lastID = nil
        registeredAt = nil
    }
}
