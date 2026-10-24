import Foundation
import Testing

@testable import Masense

// DATA_MODEL.md 저장 위치: 이전 기본 경로 스토어를 App Group 컨테이너로 옮기기
struct StoreLocationTests {
    private let root: URL
    private let legacy: URL
    private let target: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("StoreLocationTests-\(UUID().uuidString)")
        legacy = root.appendingPathComponent("AppSupport/Masense.store")
        target = root.appendingPathComponent("Group/Masense.store")
        try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    private func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    private func read(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
    }

    private func sidecar(_ url: URL, _ suffix: String) -> URL {
        URL(fileURLWithPath: url.path + suffix)
    }

    @Test func movesLegacyStoreWithJournalFiles() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try write("store", to: legacy)
        try write("wal", to: sidecar(legacy, "-wal"))
        try write("shm", to: sidecar(legacy, "-shm"))

        #expect(StoreLocation.moveIfNeeded(from: legacy, to: target) == target)
        #expect(read(target) == "store")
        #expect(read(sidecar(target, "-wal")) == "wal")
        #expect(read(sidecar(target, "-shm")) == "shm")
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(!FileManager.default.fileExists(atPath: sidecar(legacy, "-wal").path))
    }

    @Test func keepsExistingGroupStore() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try write("group", to: target)
        try write("legacy", to: legacy)

        #expect(StoreLocation.moveIfNeeded(from: legacy, to: target) == target)
        #expect(read(target) == "group")
        // 이전 파일은 건드리지 않는다
        #expect(read(legacy) == "legacy")
    }

    @Test func freshInstallUsesGroupStore() {
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(StoreLocation.moveIfNeeded(from: legacy, to: target) == target)
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test func dropsOrphanJournalAtTargetBeforeMoving() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try write("stale", to: sidecar(target, "-wal"))
        try write("store", to: legacy)

        #expect(StoreLocation.moveIfNeeded(from: legacy, to: target) == target)
        #expect(read(target) == "store")
        #expect(!FileManager.default.fileExists(atPath: sidecar(target, "-wal").path))
    }
}
