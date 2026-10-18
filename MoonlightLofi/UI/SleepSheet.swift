import SwiftUI

struct SleepSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 30
    @State private var fade = 5

    private let durations = [15, 30, 45, 60, 90]
    private let fades = [1, 3, 5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("sleep.title")
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button("common.done") { dismiss() }
                    .foregroundStyle(Palette.mist)
            }
            Text("sleep.hint")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.muted)
            Text("sleep.for")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Palette.mist)
            chipRow(durations, selection: minutes) { minutes = $0 }
            Text("sleep.fade")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Palette.mist)
            chipRow(fades.filter { $0 < minutes }, selection: min(fade, minutes - 1)) { fade = $0 }
            if model.playback.sleepPlan != nil {
                Text("sleep.active")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Palette.moon)
                Button("sleep.cancel") {
                    model.playback.cancelSleep()
                }
                .foregroundStyle(Palette.mist)
            }
            PrimaryButton(titleKey: "sleep.start") {
                model.playback.startSleep(minutes: minutes, fadeMinutes: min(fade, max(1, minutes - 1)))
                dismiss()
            }
            Button {
                model.showSleep = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    model.showDark = true
                }
            } label: {
                Label("sleep.dark", systemImage: "circle.lefthalf.filled")
                    .font(.system(.body, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.text)
            Spacer(minLength: 0)
        }
        .padding(24)
        .onAppear {
            if fade >= minutes {
                fade = min(5, max(1, minutes - 1))
            }
        }
    }

    private func chipRow(_ values: [Int], selection: Int, select: @escaping (Int) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button {
                        select(value)
                    } label: {
                        Text(L10n.tr("stats.minutes", value))
                            .font(.system(.subheadline, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(value == selection ? Palette.ink : Palette.text)
                            .background(value == selection ? Palette.moon : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct DarkScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                Text("sleep.wake")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.22))
                    .padding(.bottom, 36)
            }
        }
        .onTapGesture { model.showDark = false }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("sleep.wake"))
    }
}
