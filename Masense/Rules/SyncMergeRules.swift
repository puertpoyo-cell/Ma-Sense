import Foundation

/// iCloud로 여러 기기가 같은 기록을 주고받을 때 생기는 중복 정리 (D26, 2026-11-01 사람 결정 "폰 여러 대 사용 시 상호 업데이트, iCloud 활용").
/// 같은 키를 가진 기록이 여럿이면 가장 먼저 만든 것(`createdAt`, 같으면 id 문자열 순)을 남긴다.
/// 기준이 결정적이라 두 기기가 동시에 정리해도 같은 것을 남기고 같은 것을 지운다
enum SyncMergeRules {
    struct Item<Key: Hashable>: Equatable {
        let id: UUID
        let key: Key
        let createdAt: Date
    }

    /// 지울 id → 남길 id
    static func duplicates<Key: Hashable>(_ items: [Item<Key>]) -> [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        for group in Dictionary(grouping: items, by: \.key).values where group.count > 1 {
            let ordered = group.sorted {
                $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.id.uuidString < $1.id.uuidString
            }
            let survivor = ordered[0].id
            for item in ordered.dropFirst() { result[item.id] = survivor }
        }
        return result
    }

    /// 같은 처방으로 보는 키. 두 기기에서 같은 처방을 각각 입력한 경우 (온보딩을 두 번 한 경우 등)
    struct PrescriptionKey: Hashable {
        let startDay: Date
        let weekday: Int
        let hour: Int
        let minute: Int
        let penCount: Int
        let dosesPerPen: Int
        let intervalDays: Int
    }

    /// 같은 투약으로 보는 키. 처방(정리 뒤)·시각·부위·취소 여부가 모두 같을 때
    struct DoseKey: Hashable {
        let prescriptionID: UUID?
        let administeredAt: Date
        let site: String
        let isCancelled: Bool
    }

    /// 같은 날 습관 체크를 합칠 때 메모. 같으면 하나, 다르면 줄을 바꿔 둘 다
    static func mergedNote(_ kept: String?, _ other: String?) -> String? {
        let parts = [kept, other].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let first = parts.first else { return nil }
        return parts.count > 1 && parts[1] != first ? first + "\n" + parts[1] : first
    }
}
