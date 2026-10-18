import ActivityKit
import MoonlightCore
import SwiftUI
import WidgetKit

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Palette.moon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(phaseKey(context.state.phaseRaw)))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.mist)
                    timer(context.state)
                        .font(.system(.title2, design: .rounded).weight(.light))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Palette.night)
            .activitySystemActionForegroundColor(Palette.moon)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(LocalizedStringKey(phaseKey(context.state.phaseRaw)))
                    } icon: {
                        Image(systemName: "moon.stars.fill")
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.text)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context.state)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(Palette.text)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("brand.tagline")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Palette.mist)
                }
            } compactLeading: {
                Image(systemName: "moon.fill")
                    .foregroundStyle(Palette.moon)
            } compactTrailing: {
                timer(context.state)
                    .font(.system(.caption, design: .rounded))
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "moon.fill")
                    .foregroundStyle(Palette.moon)
            }
        }
    }

    @ViewBuilder
    private func timer(_ state: FocusActivityAttributes.ContentState) -> some View {
        if state.startedAt < state.endsAt {
            Text(timerInterval: state.startedAt...state.endsAt, countsDown: true)
                .monospacedDigit()
                .foregroundStyle(Palette.text)
        } else {
            Text(ClockFormat.mmss(0))
                .monospacedDigit()
                .foregroundStyle(Palette.text)
        }
    }

    private func phaseKey(_ raw: String) -> String {
        FocusPhase(rawValue: raw)?.titleKey ?? FocusPhase.focus.titleKey
    }
}
