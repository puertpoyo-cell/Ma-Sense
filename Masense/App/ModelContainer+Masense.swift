import Foundation
import SwiftData

extension ModelContainer {
    /// 온디바이스 전용 컨테이너. 동기화는 꺼 둔다(`cloudKitDatabase: .none`). 스키마는 CloudKit 호환 규칙을 지킨다 (DATA_MODEL.md 원칙).
    /// N-I1·D26: `AppConfig.usesCloudSync`면 앱 저장소만 개인 iCloud(`iCloud.com.puertpoyo.masense` 비공개 DB)로. 테스트·미리보기·지정 URL·시뮬레이터는 늘 `.none`
    /// 앱의 저장소는 App Group 컨테이너에 둔다 (`StoreLocation`). 테스트·미리보기는 in-memory라 App Group을 쓰지 않는다
    /// - Parameter url: 테스트에서 디스크 저장소 위치를 지정할 때만 쓴다
    static func masense(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
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
            configuration = ModelConfiguration(
                "Masense",
                schema: schema,
                url: StoreLocation.resolvedURL(),
                cloudKitDatabase: AppConfig.usesCloudSync ? .private(AppConfig.cloudKitContainer) : .none
            )
        }
        let wantsCloud = url == nil && !inMemory && AppConfig.usesCloudSync
        do {
            let container = try ModelContainer(for: schema, migrationPlan: MasenseMigrationPlan.self, configurations: [configuration])
            if url == nil, !inMemory {
                AppConfig.cloudSyncActive = wantsCloud
                if wantsCloud { AppConfig.cloudSyncFailure = nil }
            }
            return container
        } catch where wantsCloud {
            // D26-1: iCloud로 열지 못하면(권한·이전·스키마 문제) 같은 파일을 기기 안 저장소로 연다. 기록은 그대로, 동기화만 꺼진다.
            // 앱이 멈추지 않게 하고 이유를 설정 화면에 보인다
            AppConfig.cloudSyncActive = false
            AppConfig.cloudSyncFailure = Self.fullDescription(error)
            let local = ModelConfiguration("Masense", schema: schema, url: StoreLocation.resolvedURL(), cloudKitDatabase: .none)
            return try ModelContainer(for: schema, migrationPlan: MasenseMigrationPlan.self, configurations: [local])
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

    /// D26-2: 원인(어느 항목이 CloudKit 규칙에 걸렸는지)은 안쪽 오류의 userInfo에 있다. 안쪽까지 모두 펼쳐 남긴다
    static func fullDescription(_ error: Error) -> String {
        var lines = [String(describing: error)]
        var queue: [NSError] = [error as NSError]
        var seen = 0
        while let current = queue.first, seen < 20 {
            queue.removeFirst()
            seen += 1
            lines.append("[\(current.domain) \(current.code)] \(current.localizedDescription)")
            if let reason = current.localizedFailureReason { lines.append("reason: \(reason)") }
            for (key, value) in current.userInfo where key != NSUnderlyingErrorKey && key != NSDetailedErrorsKey {
                lines.append("\(key): \(value)")
            }
            if let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError { queue.append(underlying) }
            if let detailed = current.userInfo[NSDetailedErrorsKey] as? [NSError] { queue.append(contentsOf: detailed) }
        }
        return lines.joined(separator: "\n")
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
