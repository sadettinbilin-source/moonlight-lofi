import MoonlightCore
import SwiftUI

struct NowView: View {
    @Environment(AppModel.self) private var model
    var now: Date

    var body: some View {
        ZStack {
            SceneBackdrop(scene: model.activeScene)
            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            HStack {
                Spacer(minLength: 0)
                VStack(spacing: 22) {
                    header
                    scenePicker
                    Spacer(minLength: 12)
                    trackBlock
                    transport
                    secondary
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .frame(maxWidth: 560)
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("brand.kicker")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .tracking(3)
                .foregroundStyle(Palette.mist)
            Text("brand.tagline")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.muted)
        }
        .padding(.top, 8)
    }

    private var scenePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AmbientScene.allCases) { scene in
                    let locked = scene.isPro && !model.isPro
                    let selected = scene == model.activeScene
                    Button {
                        model.select(scene: scene)
                    } label: {
                        HStack(spacing: 6) {
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                            }
                            Text(LocalizedStringKey(scene.titleKey))
                                .font(.system(.subheadline, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(selected ? Palette.ink : Palette.text)
                        .background(selected ? Palette.moon : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey(scene.titleKey)))
                    .accessibilityHint(Text(locked ? "scene.locked" : ""))
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityLabel(Text("a11y.scenes"))
    }

    private var trackBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let track = model.playback.current {
                HStack {
                    Text(LocalizedStringKey(track.mood))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.mist)
                    Spacer()
                    if track.isPro {
                        Text("badge.pro")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Palette.moon.opacity(0.2), in: Capsule())
                            .foregroundStyle(Palette.moon)
                    }
                }
                Text(track.title)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
            } else {
                Text("now.choose")
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.text)
            }
            if let errorKey = model.playback.errorKey {
                Text(LocalizedStringKey(errorKey))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Palette.moon)
            }
            slider
        }
    }

    private var slider: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { model.playback.currentTime },
                    set: { model.playback.previewScrub($0) }
                ),
                in: 0...max(model.playback.duration, 1),
                onEditingChanged: { editing in
                    if !editing {
                        model.playback.commitScrub(model.playback.currentTime)
                    }
                }
            )
            .tint(Palette.moon)
            .accessibilityLabel(Text("a11y.progress"))
            HStack {
                Text(ClockFormat.mmss(model.playback.currentTime))
                Spacer()
                Text(ClockFormat.mmss(model.playback.duration))
            }
            .font(.system(.caption, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Palette.muted)
        }
    }

    private var transport: some View {
        HStack(spacing: 18) {
            IconCircle(
                systemImage: "shuffle",
                labelKey: "action.shuffle",
                active: model.playback.shuffle
            ) {
                model.toggleShuffle()
            }
            IconCircle(systemImage: "backward.fill", labelKey: "action.previous") {
                model.playback.skipBackward()
            }
            IconCircle(
                systemImage: model.playback.isPlaying ? "pause.fill" : "play.fill",
                labelKey: model.playback.isPlaying ? "action.pause" : "action.play",
                prominent: true
            ) {
                if model.playback.current == nil, let first = model.catalog.tracks.first {
                    model.play(first)
                } else {
                    model.playback.togglePlay()
                }
            }
            IconCircle(systemImage: "forward.fill", labelKey: "action.next") {
                model.playback.skipForward()
            }
            IconCircle(
                systemImage: model.playback.loop == .one ? "repeat.1" : "repeat",
                labelKey: loopKey,
                active: model.playback.loop != .off
            ) {
                model.cycleLoop()
            }
        }
    }

    private var secondary: some View {
        HStack(spacing: 12) {
            Button {
                model.showSleep = true
            } label: {
                Label("action.sleep", systemImage: "moon.zzz")
                    .font(.system(.subheadline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.playback.sleepPlan == nil ? Palette.text : Palette.moon)

            Button {
                Task { await model.downloadCurrent() }
            } label: {
                downloadLabel
                    .font(.system(.subheadline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.text)
        }
    }

    @ViewBuilder
    private var downloadLabel: some View {
        if let id = model.playback.current?.id, model.downloads.inFlight.contains(id) {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel(Text("action.downloading"))
        } else if let id = model.playback.current?.id, model.downloads.downloadedIDs.contains(id) {
            Label("action.downloaded", systemImage: "checkmark.circle.fill")
        } else {
            Label("action.download", systemImage: "arrow.down.circle")
        }
    }

    private var loopKey: String {
        switch model.playback.loop {
        case .off: return "loop.off"
        case .one: return "loop.one"
        case .all: return "loop.all"
        }
    }
}
