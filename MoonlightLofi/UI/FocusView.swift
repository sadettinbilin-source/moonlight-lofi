import MoonlightCore
import SwiftUI

struct FocusView: View {
    @Environment(AppModel.self) private var model
    var now: Date

    var body: some View {
        MoonPage {
            ScrollView {
                VStack(spacing: 28) {
                    FocusRing(
                        progress: FocusTimerEngine.progress(in: model.focus.snapshot, now: now),
                        time: ClockFormat.mmss(FocusTimerEngine.remaining(in: model.focus.snapshot, now: now)),
                        phaseKey: phaseKey
                    )
                    .frame(maxWidth: 280)
                    .padding(.top, 24)

                    if let finished = model.focus.snapshot.lastFinished, !model.focus.snapshot.isRunning {
                        Text(finished == .focus ? "focus.complete" : "focus.breakComplete")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Palette.mist)
                    }

                    PrimaryButton(titleKey: primaryKey, systemImage: primarySymbol) {
                        if model.focus.snapshot.isRunning {
                            model.focus.pause()
                        } else {
                            model.focus.begin()
                        }
                    }

                    if model.focus.snapshot.isRunning || model.focus.snapshot.remainingWhenPaused != nil {
                        Button("focus.end") {
                            model.focus.stop()
                        }
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Palette.muted)
                    }

                    settings
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private var phaseKey: String {
        if model.focus.snapshot.isRunning || model.focus.snapshot.remainingWhenPaused != nil {
            return model.focus.snapshot.phase.titleKey
        }
        let suggested = model.focus.snapshot.suggestedPhase
        return (suggested == .idle ? FocusPhase.focus : suggested).titleKey
    }

    private var primaryKey: String {
        if model.focus.snapshot.isRunning { return "focus.pause" }
        if model.focus.snapshot.remainingWhenPaused != nil { return "focus.resume" }
        switch model.focus.snapshot.suggestedPhase {
        case .shortBreak: return "focus.startBreak"
        case .longBreak: return "focus.startLongBreak"
        case .focus, .idle: return "focus.start"
        }
    }

    private var primarySymbol: String {
        model.focus.snapshot.isRunning ? "pause.fill" : "play.fill"
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.focus.snapshot.isRunning {
                Text("focus.appliesNext")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
            minuteStepper(
                titleKey: "focus.length",
                value: Int(model.focus.snapshot.settings.focusLength / 60),
                range: 5...90,
                step: 5
            ) { minutes in
                var settings = model.focus.snapshot.settings
                settings.focusLength = TimeInterval(minutes * 60)
                model.focus.update(settings)
            }
            minuteStepper(
                titleKey: "focus.shortBreak",
                value: Int(model.focus.snapshot.settings.shortBreakLength / 60),
                range: 1...30,
                step: 1
            ) { minutes in
                var settings = model.focus.snapshot.settings
                settings.shortBreakLength = TimeInterval(minutes * 60)
                model.focus.update(settings)
            }
            minuteStepper(
                titleKey: "focus.longBreak",
                value: Int(model.focus.snapshot.settings.longBreakLength / 60),
                range: 5...45,
                step: 5
            ) { minutes in
                var settings = model.focus.snapshot.settings
                settings.longBreakLength = TimeInterval(minutes * 60)
                model.focus.update(settings)
            }
            minuteStepper(
                titleKey: "focus.untilLong",
                value: model.focus.snapshot.settings.sessionsUntilLongBreak,
                range: 2...8,
                step: 1,
                suffixKey: nil
            ) { count in
                var settings = model.focus.snapshot.settings
                settings.sessionsUntilLongBreak = count
                model.focus.update(settings)
            }
            Toggle(isOn: Binding(
                get: { model.focus.snapshot.settings.autoContinue },
                set: { value in
                    var settings = model.focus.snapshot.settings
                    settings.autoContinue = value
                    model.focus.update(settings)
                }
            )) {
                Text("focus.autoContinue")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.text)
            }
            .tint(Palette.moon)
        }
        .padding(18)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func minuteStepper(
        titleKey: String,
        value: Int,
        range: ClosedRange<Int>,
        step: Int,
        suffixKey: String? = "stats.minutes",
        set: @escaping (Int) -> Void
    ) -> some View {
        Stepper(
            value: Binding(get: { value }, set: set),
            in: range,
            step: step
        ) {
            HStack {
                Text(LocalizedStringKey(titleKey))
                Spacer()
                if let suffixKey {
                    Text(L10n.tr(suffixKey, value))
                        .monospacedDigit()
                        .foregroundStyle(Palette.mist)
                } else {
                    Text("\(value)")
                        .monospacedDigit()
                        .foregroundStyle(Palette.mist)
                }
            }
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Palette.text)
        }
    }
}

struct FocusRing: View {
    var progress: Double
    var time: String
    var phaseKey: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 16)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(Palette.moon, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 6) {
                Text(time)
                    .font(.system(size: 56, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Palette.text)
                Text(LocalizedStringKey(phaseKey))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.mist)
            }
            .padding(28)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("focus.ring"))
        .accessibilityValue(Text(time))
    }
}
