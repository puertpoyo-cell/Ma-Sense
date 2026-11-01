#if DEBUG
import CoreData
import SwiftData

/// D26 개발용: iCloud 개발 환경에 기록 종류(스키마)를 한 번에 만든다.
/// TestFlight·App Store 빌드는 운영 환경을 쓰는데, 운영 환경에는 개발 환경에서 만든 스키마를 CloudKit Console에서 "Deploy"해야 기록이 오간다.
/// 사람이 Xcode로 실기기에 DEBUG 빌드를 띄워 설정 > 개발용 버튼을 한 번 누른 뒤 Console에서 배포한다 (TESTFLIGHT.md 7).
/// 스키마가 바뀔 때마다(VersionedSchema 추가) 다시 한 번
enum CloudKitSchemaInitializer {
    static func run() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CloudKitSchema-\(UUID().uuidString).store")
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: AppConfig.cloudKitContainer)
        description.shouldAddStoreAsynchronously = false

        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: CurrentSchema.models) else {
            throw CocoaError(.featureUnsupported)
        }
        let container = NSPersistentCloudKitContainer(name: "MasenseSchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        try container.initializeCloudKitSchema()
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
        try? FileManager.default.removeItem(at: url)
    }
}
#endif
