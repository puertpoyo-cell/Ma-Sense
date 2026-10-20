import Foundation
import SwiftData

extension ModelContainer {
    /// 온디바이스 전용 컨테이너. 서버·CloudKit 동기화 없음 (CLAUDE.md 스택, DATA_MODEL.md 원칙).
    static func masense(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        // in-memory 컨테이너는 테스트·미리보기마다 독립적이어야 하므로 이름을 다르게 둔다
        let name = inMemory ? "Masense-\(UUID().uuidString)" : "Masense"
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// `#Preview` 전용 in-memory 컨테이너 (CLAUDE.md 테스트·빌드).
    @MainActor
    static var preview: ModelContainer {
        do {
            return try masense(inMemory: true)
        } catch {
            fatalError("Preview ModelContainer could not be created: \(error)")
        }
    }
}
