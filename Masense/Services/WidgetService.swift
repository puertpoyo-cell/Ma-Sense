import Foundation
import SwiftData
import WidgetKit

/// D6 위젯 요약을 App Group에 쓰고 위젯을 다시 그리게 한다. 테스트·미리보기는 Fake
protocol WidgetPublishing: AnyObject {
    func publish(_ snapshot: WidgetSnapshot)
}

final class WidgetService: WidgetPublishing {
    /// 마지막으로 쓴 내용 (`updatedAt` 제외). 같으면 위젯을 다시 그리지 않는다
    private var lastPublished: WidgetSnapshot?

    func publish(_ snapshot: WidgetSnapshot) {
        var comparable = snapshot
        comparable.updatedAt = .distantPast
        guard comparable != lastPublished else { return }
        do {
            try snapshot.write()
            lastPublished = comparable
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // App Group 서명이 없는 빌드(CI 시뮬레이터 등)는 쓸 곳이 없다. 위젯만 비고 앱은 그대로
        }
    }

    /// 저장된 데이터로 요약을 만든다 (`now` 주입 지점은 부르는 쪽)
    @MainActor
    static func snapshot(context: ModelContext, now: Date, calendar: Calendar) -> WidgetSnapshot {
        let prescription = try? Prescription.active(in: context)
        let allDoses = (try? context.fetch(FetchDescriptor<Dose>()))?.map(\.snapshot) ?? []
        return WidgetRules.snapshot(
            prescription: prescription?.snapshot,
            doses: prescription?.doseSnapshots ?? [],
            allDoses: allDoses,
            now: now,
            calendar: calendar
        )
    }
}

final class FakeWidgetService: WidgetPublishing {
    private(set) var published: [WidgetSnapshot] = []

    func publish(_ snapshot: WidgetSnapshot) {
        published.append(snapshot)
    }
}
