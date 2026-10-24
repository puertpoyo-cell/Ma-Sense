import SwiftUI
import WidgetKit

/// 홈·잠금화면 위젯 "다음 투약" (D6, SCREENS.md 위젯). 앱이 App Group에 써 둔 `WidgetSnapshot`만 읽는다.
/// 사실만: 다음 투약까지 남은 날, 예정 시각, 마지막 부위, 남은 회차. 약 이름·용량·"주사" 단어 없음 (COMPLIANCE.md 3.3)
struct NextDoseWidget: Widget {
    static let kind = "NextDoseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NextDoseProvider()) { entry in
            NextDoseWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.midnight }
                .widgetURL(entry.opensDoseLog ? WidgetSnapshot.logDoseURL : nil)
        }
        .configurationDisplayName("widget.nextDose.name")
        .description("widget.nextDose.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct NextDoseEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    var countdown: WidgetCountdown { snapshot.countdown(at: date, calendar: .current) }
    var showsDone: Bool { snapshot.showsDone(at: date, calendar: .current) }

    /// 예정일이거나 지났으면 누르면 바로 투약 기록. 그 밖에는 앱만 연다
    var opensDoseLog: Bool {
        switch countdown {
        case .today, .overdue: return true
        default: return false
        }
    }
}

struct NextDoseProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextDoseEntry {
        NextDoseEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextDoseEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.preview : (WidgetSnapshot.read() ?? WidgetSnapshot.empty)
        completion(NextDoseEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextDoseEntry>) -> Void) {
        let snapshot = WidgetSnapshot.read() ?? .empty
        let entries = snapshot.timelineDates(from: .now, calendar: .current).map { NextDoseEntry(date: $0, snapshot: snapshot) }
        // 마지막 항목 뒤에는 다시 읽는다. 기록이 바뀌면 앱이 바로 다시 그리게 한다 (WidgetService)
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

extension WidgetSnapshot {
    /// 앱을 아직 열지 않아 요약이 없을 때
    static var empty: WidgetSnapshot {
        WidgetSnapshot(phase: .noPrescription, updatedAt: .now)
    }

    /// 위젯 갤러리 미리보기. 약물명·용량 없음
    static var preview: WidgetSnapshot {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: .now)) ?? .now
        return WidgetSnapshot(
            phase: .upcoming,
            scheduledDate: calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day),
            lastDoseDate: calendar.date(byAdding: .day, value: -5, to: .now),
            lastSiteName: String(localized: "widget.preview.site"),
            remainingDoses: 6,
            updatedAt: .now
        )
    }
}

// MARK: - 뷰

struct NextDoseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextDoseEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                countdownBlock
                Rectangle().fill(WidgetPalette.hairline).frame(width: 1)
                detailsBlock
            }
        default:
            countdownBlock
        }
    }

    // MARK: 홈 화면

    private var countdownBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.caption2.weight(.medium))
                .foregroundStyle(WidgetPalette.inkSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if let big = bigText {
                Text(verbatim: big)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WidgetPalette.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            if let scheduled = scheduledDate {
                Text(scheduled.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated).hour().minute()))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(WidgetPalette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("widget.lastSite")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WidgetPalette.inkSecondary)
                if let lastDate = entry.snapshot.lastDoseDate {
                    Text(entry.snapshot.lastSiteName ?? String(localized: "widget.site.unknown"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(lastDate.formatted(.dateTime.month(.defaultDigits).day()))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(WidgetPalette.inkSecondary)
                } else {
                    Text(verbatim: "—")
                        .font(.subheadline)
                        .foregroundStyle(WidgetPalette.inkSecondary)
                }
            }
            if let remaining = entry.snapshot.remainingDoses {
                VStack(alignment: .leading, spacing: 2) {
                    Text("widget.remaining")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(WidgetPalette.inkSecondary)
                    Text("widget.remaining.value \(remaining)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetPalette.ink)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: 잠금 화면

    private var rectangular: some View {
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
    }

    private var circular: some View {
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

    private var inline: some View {
        Group {
            if let big = bigText {
                Text("widget.inline \(big)")
            } else {
                Text(caption)
            }
        }
    }

    // MARK: 문구

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

/// 앱 `Color+Tokens.swift`의 다크 토큰과 같은 값 (DESIGN_SYSTEM.md 2). 위젯은 앱 모듈을 쓰지 않아 따로 둔다
enum WidgetPalette {
    static let midnight = Color(red: 0x0B / 255, green: 0x12 / 255, blue: 0x20 / 255)
    static let ink = Color(red: 0xF2 / 255, green: 0xF5 / 255, blue: 0xFA / 255)
    static let inkSecondary = Color(red: 0x9A / 255, green: 0xA7 / 255, blue: 0xBD / 255)
    static let hairline = Color.white.opacity(0.12)
}

#Preview(as: .systemMedium) {
    NextDoseWidget()
} timeline: {
    NextDoseEntry(date: .now, snapshot: .preview)
}
