import MoonlightCore
import SwiftUI
import WidgetKit

struct FocusEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
}

struct FocusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        completion(FocusEntry(date: Date(), snapshot: WidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        let snapshot = WidgetStore.load()
        let entry = FocusEntry(date: Date(), snapshot: snapshot)
        let refresh: Date
        if snapshot.isRunning, let endsAt = snapshot.endsAt {
            refresh = endsAt.addingTimeInterval(1)
        } else {
            refresh = Date().addingTimeInterval(30 * 60)
        }
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct FocusHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FocusHomeWidget", provider: FocusTimelineProvider()) { entry in
            FocusWidgetView(entry: entry)
                .containerBackground(Palette.night, for: .widget)
        }
        .configurationDisplayName(Text("tab.focus"))
        .description(Text("widget.start"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FocusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: FocusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("brand.kicker", systemImage: "moon.stars.fill")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Palette.mist)
            if showsTimer, let range = timerRange {
                Text(LocalizedStringKey(entry.snapshot.phase.titleKey))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.mist)
                Text(timerInterval: range, countsDown: true)
                    .font(.system(size: family == .systemSmall ? 32 : 40, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Palette.text)
            } else {
                Text("widget.start")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.tr("streak.days", entry.snapshot.streak))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.moon)
                if family != .systemSmall {
                    Text(L10n.tr("stats.minutes", entry.snapshot.totalFocusMinutes))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var showsTimer: Bool {
        entry.snapshot.isRunning && timerRange != nil
    }

    private var timerRange: ClosedRange<Date>? {
        guard
            let startedAt = entry.snapshot.startedAt,
            let endsAt = entry.snapshot.endsAt,
            startedAt < endsAt
        else { return nil }
        return startedAt...endsAt
    }
}
