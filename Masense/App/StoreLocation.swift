import Foundation

/// SwiftData 스토어 파일 위치 (DATA_MODEL.md "저장 위치 — App Group 컨테이너").
/// v2 위젯·Live Activity·Watch가 같은 스토어를 읽도록 App Group 컨테이너에 둔다.
enum StoreLocation {
    static let appGroupID = "group.com.puertpoyo.masense"
    static let fileName = "Masense.store"

    /// SQLite 저장소 파일과 저널 파일 접미사
    static let fileSuffixes = ["", "-shm", "-wal"]

    /// App Group 컨테이너 안의 스토어. 이전 기본 경로에 스토어가 있으면 먼저 옮긴다.
    /// 그룹 컨테이너를 쓸 수 없으면(App Group 서명이 없는 빌드) 앱 기본 경로를 그대로 쓴다
    static func resolvedURL(fileManager: FileManager = .default) -> URL {
        let legacy = URL.applicationSupportDirectory.appendingPathComponent(fileName)
        guard let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return legacy
        }
        return moveIfNeeded(from: legacy, to: group.appendingPathComponent(fileName), fileManager: fileManager)
    }

    /// D4-A 이전 빌드가 앱 기본 경로에 만든 스토어를 그룹 컨테이너로 옮긴다.
    /// 새 위치에 이미 스토어가 있거나 옮길 것이 없으면 새 위치. 복사를 다 마친 뒤에만 이전 파일을 지우고,
    /// 하나라도 실패하면 복사본을 지우고 이전 위치를 그대로 쓴다 (기록을 잃지 않게)
    static func moveIfNeeded(from legacy: URL, to target: URL, fileManager: FileManager = .default) -> URL {
        guard !fileManager.fileExists(atPath: target.path), fileManager.fileExists(atPath: legacy.path) else {
            return target
        }
        let pairs = fileSuffixes
            .map { (URL(fileURLWithPath: legacy.path + $0), URL(fileURLWithPath: target.path + $0)) }
            .filter { fileManager.fileExists(atPath: $0.0.path) }
        do {
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            // 새 위치에 본 파일 없이 남은 저널 파일은 짝이 없으므로 지운다
            for suffix in fileSuffixes.dropFirst() {
                try? fileManager.removeItem(at: URL(fileURLWithPath: target.path + suffix))
            }
            for (from, to) in pairs {
                try fileManager.copyItem(at: from, to: to)
            }
        } catch {
            for (_, to) in pairs {
                try? fileManager.removeItem(at: to)
            }
            return legacy
        }
        for (from, _) in pairs {
            try? fileManager.removeItem(at: from)
        }
        return target
    }
}
