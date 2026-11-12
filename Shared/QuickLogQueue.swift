import Foundation

/// D51 위젯에서 누른 "투약 기록"을 앱이 저장하기 전까지 App Group에 모아 둔다 (누른 시각 목록).
/// 위젯은 SwiftData 저장소를 열지 않는다 (CLAUDE.md). 앱이 다음에 깨어날 때 저장소에 넣고 비운다.
/// Foundation만 쓴다
enum QuickLogQueue {
    static let fileName = "QuickLogQueue.json"

    static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    static func read(from url: URL? = QuickLogQueue.fileURL) -> [Date] {
        guard let url, let data = try? Data(contentsOf: url),
              let seconds = try? JSONDecoder().decode([Double].self, from: data) else { return [] }
        return seconds.map(Date.init(timeIntervalSince1970:)).sorted()
    }

    static func append(_ date: Date, to url: URL? = QuickLogQueue.fileURL) {
        guard let url else { return }
        let seconds = (read(from: url) + [date]).map(\.timeIntervalSince1970)
        guard let data = try? JSONEncoder().encode(seconds) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear(at url: URL? = QuickLogQueue.fileURL) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

extension WidgetSnapshot {
    /// 위젯에서 기록을 누른 바로 뒤의 모습. 앱이 저장소에 넣고 다시 쓰기 전까지 위젯이 "기록 완료"와 다음 예정(7일 뒤)을 보이게 한다.
    /// 이미 기록한 마디거나 처방이 없으면 그대로
    func afterQuickLog(at date: Date, calendar: Calendar) -> WidgetSnapshot {
        guard phase == .upcoming, let scheduled = scheduledDate else { return self }
        var copy = self
        let remaining = remainingDoses.map { max($0 - 1, 0) }
        copy.phase = .done
        copy.remainingDoses = remaining
        copy.scheduledDate = remaining == 0 ? nil : calendar.date(byAdding: .day, value: 7, to: scheduled)
        copy.lastDoseDate = date
        copy.lastSiteName = nil
        copy.updatedAt = date
        return copy
    }
}
