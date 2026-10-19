import MoonlightCore
import SwiftUI

struct NowView: View {
    @Environment(AppModel.self) private var model
    var now: Date

    var body: some View {
        ZStack {
            if model.activeScene.isIllustrated {
                IllustratedScene(scene: model.activeScene)
            } else {
                SceneBackdrop(scene: model.activeScene)
            }
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
        VStack(alignment: .leading, spacing: 10) {
            if model.offersSleepScene {
                sleepSuggestion
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(AmbientScene.allCases) { scene in
                        sceneChip(scene)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .accessibilityIdentifier("scene.picker")
        }
        .accessibilityLabel(Text("a11y.scenes"))
    }

    private var sleepSuggestion: some View {
        HStack(spacing: 10) {
            Text("scene.sleepSuggest")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button {
                model.acceptSleepScene()
            } label: {
                Text("scene.sleepSuggest.use")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Palette.moon, in: Capsule())
            }
            .buttonStyle(.plain)
            Button {
                model.dismissSleepScene()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("scene.sleepSuggest.dismiss"))
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sceneChip(_ scene: AmbientScene) -> some View {
        let locked = scene.isPro && !model.isPro
        let selected = scene == model.activeScene
        return Button {
            model.select(scene: scene)
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    SceneThumbnail(scene: scene)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(selected ? Palette.moon : Color.white.opacity(0.2), lineWidth: selected ? 2 : 1)
                        }
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .padding(5)
                            .background(Color.black.opacity(0.55), in: Circle())
                            .padding(5)
                    }
                }
                sceneTitle(L10n.tr(scene.titleKey), selected: selected)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scene.\(scene.rawValue)")
        .accessibilityLabel(Text(verbatim: L10n.tr(scene.titleKey)))
        .accessibilityHint(Text(locked ? "scene.locked" : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Breaks only on spaces. A single word scales down instead of splitting mid-word.
    private func sceneTitle(_ title: String, selected: Bool) -> some View {
        let lines = SceneTitleLayout.lines(for: title)
        return VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .font(.system(size: 11, weight: selected ? .semibold : .regular, design: .rounded))
        .foregroundStyle(selected ? Palette.moon : Palette.text)
        .frame(width: 88)
        .accessibilityHidden(true)
    }

    private var trackBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let track = model.playback.current {
                HStack {
                    Text(trackMeta(track))
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
                prominent: true,
                identifier: "transport.play",
                value: model.playback.isPlaying ? "playing" : "paused"
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
            .accessibilityIdentifier("action.sleep")
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

    private func trackMeta(_ track: Track) -> String {
        var parts = [L10n.tr(track.mood)]
        if let key = track.musicalKey {
            parts.append(L10n.tr("key.\(key)"))
        }
        if let bpm = track.bpm {
            parts.append(L10n.tr("meta.bpm", bpm))
        }
        return parts.joined(separator: " · ")
    }

    private var loopKey: String {
        switch model.playback.loop {
        case .off: return "loop.off"
        case .one: return "loop.one"
        case .all: return "loop.all"
        }
    }
}
