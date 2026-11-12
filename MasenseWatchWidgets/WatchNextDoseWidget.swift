import SwiftUI
import WidgetKit

/// 시계 화면 "다음 투약": D-n, 오늘, 지남. 사실만 (COMPLIANCE.md 3.3 약 이름·용량 없음)
struct WatchNextDoseWidget: Widget {
    static let kind = "WatchNextDoseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: WatchNextDoseProvider()) { entry in
            WatchNextDoseView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("widget.nextDose.name")
        .description("widget.nextDose.description")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct WatchNextDoseEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    var countdown: WidgetCountdown { snapshot.countdown(at: date, calendar: .current) }
    var showsDone: Bool { snapshot.showsDone(at: date, calendar: .current) }
}

struct WatchNextDoseProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchNextDoseEntry {
        WatchNextDoseEntry(date: .now, snapshot: .watchPreview)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchNextDoseEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.watchPreview : (WidgetSnapshot.read() ?? .watchEmpty)
        completion(WatchNextDoseEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchNextDoseEntry>) -> Void) {
        let snapshot = WidgetSnapshot.read() ?? .watchEmpty
        let entries = snapshot.timelineDates(from: .now, calendar: .current).map { WatchNextDoseEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

extension WidgetSnapshot {
    /// 워치 앱을 아직 열지 않아 요약이 없을 때
    static var watchEmpty: WidgetSnapshot {
        WidgetSnapshot(phase: .noPrescription, updatedAt: .now)
    }

    static var watchPreview: WidgetSnapshot {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: .now)) ?? .now
        return WidgetSnapshot(phase: .upcoming, scheduledDate: calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day), remainingDoses: 6, updatedAt: .now)
    }
}

struct WatchNextDoseView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchNextDoseEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            if let big = bigText {
                Text("widget.inline \(big)")
            } else {
                Text(caption)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(caption)
                    .font(.caption2)
                    .lineLimit(1)
                if let big = bigText {
                    Text(verbatim: big)
                        .font(.headline)
                        .monospacedDigit()
                }
                if let scheduled = scheduledDate {
                    Text(scheduled.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetAccentable()
        case .accessoryCorner:
            Text(verbatim: bigText ?? "—")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .widgetLabel { Text(caption) }
        default:
            ZStack {
                AccessoryWidgetBackground()
                Text(verbatim: bigText ?? "—")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .padding(4)
            }
            .widgetAccentable()
        }
    }

    private var caption: LocalizedStringKey {
        if entry.showsDone { return "widget.caption.done" }
        switch entry.countdown {
        case .noPrescription: return "widget.caption.noPrescription"
        case .exhausted: return "widget.caption.exhausted"
        case .daysLeft, .today: return "widget.caption.next"
        case .overdue: return "widget.caption.overdue"
        }
    }

    /// D-n, D-Day, D+n. 처방이 없거나 소진이면 nil
    private var bigText: String? {
        switch entry.countdown {
        case .noPrescription, .exhausted: return nil
        case let .daysLeft(days, _): return "D-\(days)"
        case .today: return "D-Day"
        case let .overdue(days, _): return days == 0 ? "D-Day" : "D+\(days)"
        }
    }

    private var scheduledDate: Date? {
        switch entry.countdown {
        case let .daysLeft(_, scheduled), let .today(scheduled), let .overdue(_, scheduled): return scheduled
        case .noPrescription, .exhausted: return nil
        }
    }
}
