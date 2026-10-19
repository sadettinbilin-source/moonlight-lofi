import SwiftUI

struct SleepSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 30
    @State private var fade = 5

    private let durations = [15, 30, 45, 60, 90]
    private let fades = [1, 3, 5, 10]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("sleep.title")
                        .font(.system(.title2, design: .rounded).weight(.medium))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Button("common.done") { dismiss() }
                        .accessibilityIdentifier("sleep.done")
                        .foregroundStyle(Palette.mist)
                }
                Text("sleep.hint")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
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
                        .fixedSize(horizontal: false, vertical: true)
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
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .background {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("screen.sleep")
        }
        .onAppear {
            if fade >= minutes {
                fade = min(5, max(1, minutes - 1))
            }
        }
    }

    private func chipRow(_ values: [Int], selection: Int, select: @escaping (Int) -> Void) -> some View {
        ChipFlow(spacing: 8) {
            ForEach(values, id: \.self) { value in
                Button {
                    select(value)
                } label: {
                    Text(L10n.tr("stats.minutes", value))
                        .font(.system(.subheadline, design: .rounded))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(value == selection ? Palette.ink : Palette.text)
                        .background(value == selection ? Palette.moon : Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = rows(in: width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width == .infinity ? 0 : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for item in row.items {
                item.view.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [ChipRow] {
        var rows: [ChipRow] = []
        var items: [ChipItem] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let next = rowWidth == 0 ? size.width : rowWidth + spacing + size.width
            if rowWidth > 0, next > width {
                rows.append(ChipRow(items: items, height: rowHeight))
                items = []
                rowWidth = 0
                rowHeight = 0
            }
            items.append(ChipItem(view: subview, size: size))
            rowWidth = rowWidth == 0 ? size.width : rowWidth + spacing + size.width
            rowHeight = max(rowHeight, size.height)
        }
        if !items.isEmpty {
            rows.append(ChipRow(items: items, height: rowHeight))
        }
        return rows
    }
}

private struct ChipItem {
    var view: LayoutSubview
    var size: CGSize
}

private struct ChipRow {
    var items: [ChipItem]
    var height: CGFloat
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
