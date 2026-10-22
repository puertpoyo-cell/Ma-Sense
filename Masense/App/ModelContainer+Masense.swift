import Foundation
import SwiftData

extension ModelContainer {
    /// 온디바이스 전용 컨테이너. 서버·CloudKit 동기화 없음 (CLAUDE.md 스택, DATA_MODEL.md 원칙).
    /// 현재 스키마는 V3이고, V1·V2 저장소는 `MasenseMigrationPlan`으로 경량 마이그레이션된다.
    /// - Parameter url: 테스트에서 디스크 저장소 위치를 지정할 때만 쓴다
    static func masense(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            // in-memory 컨테이너는 테스트·미리보기마다 독립적이어야 하므로 이름을 다르게 둔다
            let name = inMemory ? "Masense-\(UUID().uuidString)" : "Masense"
            configuration = ModelConfiguration(
                name,
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(for: schema, migrationPlan: MasenseMigrationPlan.self, configurations: [configuration])
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
