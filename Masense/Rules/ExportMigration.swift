import Foundation

/// 내보내기 파일의 formatVersion 간 변환 (EXPORT_FORMAT.md 가져오기 규칙 3). JSON 객체 단위의 순수 함수.
/// 이전 버전의 Codable 타입을 남기지 않고, 객체를 한 단계씩 고쳐 현재 `ExportDocument`로 읽히게 만든다.
/// v1이 첫 버전이라 아직 단계가 없다. formatVersion을 올릴 때 `steps[1] = v1to2`처럼 더하고 이전 버전 fixture로 테스트한다.
enum ExportMigration {
    typealias Step = ([String: Any]) throws -> [String: Any]

    /// 키는 출발 버전. `steps[1]`은 v1 → v2
    static let steps: [Int: Step] = [:]

    /// `version`에서 `target`까지 단계를 차례로 적용하고 `formatVersion`을 맞춘다. 빠진 단계가 있으면 읽을 수 없는 파일로 본다
    static func migrate(
        _ object: [String: Any],
        from version: Int,
        to target: Int = ExportDocument.currentFormatVersion,
        steps: [Int: Step] = ExportMigration.steps
    ) throws -> [String: Any] {
        guard version >= 1, version <= target else { throw ExportCodec.ImportError.unreadable }
        var object = object
        for from in version..<target {
            guard let step = steps[from] else { throw ExportCodec.ImportError.unreadable }
            object = try step(object)
            object["formatVersion"] = from + 1
        }
        return object
    }
}
