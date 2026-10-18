import MoonlightCore
import SwiftUI

struct LibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        MoonPage {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("library.header")
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.text)
                        .padding(.top, 12)
                    Text("library.placeholderNote")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.muted)
                    if let errorKey = model.catalogErrorKey {
                        Text(LocalizedStringKey(errorKey))
                            .foregroundStyle(Palette.moon)
                    }
                    if model.catalog.tracks.isEmpty {
                        Text("library.empty")
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 24)
                    }
                    ForEach(model.catalog.tracks) { track in
                        trackRow(track)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }

    private func trackRow(_ track: Track) -> some View {
        let locked = track.isPro && !model.isPro
        let current = model.playback.current?.id == track.id
        return Button {
            model.play(track)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: current && model.playback.isPlaying ? "waveform" : "moon.fill")
                    .frame(width: 36)
                    .foregroundStyle(Palette.moon)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(Palette.text)
                    Text(LocalizedStringKey(track.mood))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 8)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.mist)
                } else if !track.isReadyToPlay {
                    Text("badge.addAudio")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Palette.moon)
                } else if model.downloads.downloadedIDs.contains(track.id) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Palette.mist)
                }
                Text(ClockFormat.mmss(track.duration))
                    .font(.system(.caption, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.muted)
            }
            .padding(14)
            .background(Color.white.opacity(current ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if model.downloads.downloadedIDs.contains(track.id) {
                Button(role: .destructive) {
                    model.downloads.remove(id: track.id)
                } label: {
                    Text("action.removeDownload")
                }
            }
        }
    }
}
