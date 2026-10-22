import Foundation
import SwiftData

extension ModelContainer {
    /// 온디바이스 전용 컨테이너. 동기화는 꺼 둔다(`cloudKitDatabase: .none`). 스키마는 CloudKit 호환 규칙을 지킨다 (DATA_MODEL.md 원칙).
    /// 앱의 저장소는 App Group 컨테이너에 둔다 (`StoreLocation`). 테스트·미리보기는 in-memory라 App Group을 쓰지 않는다
    /// - Parameter url: 테스트에서 디스크 저장소 위치를 지정할 때만 쓴다
    static func masense(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else if inMemory {
            // in-memory 컨테이너는 테스트·미리보기마다 독립적이어야 하므로 이름을 다르게 둔다
            configuration = ModelConfiguration(
                "Masense-\(UUID().uuidString)",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration("Masense", schema: schema, url: StoreLocation.resolvedURL(), cloudKitDatabase: .none)
        }
        do {
            return try ModelContainer(for: schema, migrationPlan: MasenseMigrationPlan.self, configurations: [configuration])
        } catch {
            #if DEBUG
            // 출시 전 스키마 재정리(2026-10-22) 이전의 개발용 저장소는 버전을 알아보지 못한다. 개발 빌드에서만 지우고 새로 만든다
            guard !inMemory, url == nil else { throw error }
            removeStoreFiles(at: configuration.url)
            return try ModelContainer(for: schema, migrationPlan: MasenseMigrationPlan.self, configurations: [configuration])
            #else
            throw error
            #endif
        }
    }

    /// SQLite 저장소 파일과 저널 파일
    static func removeStoreFiles(at url: URL) {
        for suffix in StoreLocation.fileSuffixes {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
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
