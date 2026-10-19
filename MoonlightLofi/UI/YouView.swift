import SwiftUI

struct YouView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        MoonPage {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("tab.you")
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.text)
                        .padding(.top, 12)

                    if model.isPro {
                        stats
                    } else {
                        lockedStats
                    }

                    proCard
                    notifications
                    about
                    Text(versionLine)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .task {
            await model.refreshNotifications()
        }
    }

    private var stats: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("stats.title")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Palette.text)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("stats.minutes", model.totalFocusMinutes))
                            .font(.system(size: 36, weight: .light, design: .rounded))
                            .foregroundStyle(Palette.text)
                        Text("stats.total")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Text(L10n.tr("streak.days", model.streak))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.moon)
                }
                if model.totalFocusMinutes == 0 {
                    Text("stats.empty")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Palette.muted)
                } else {
                    Text("stats.week")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.muted)
                    weekChart
                }
            }
        }
    }

    private var weekChart: some View {
        let peak = max(model.week.map(\.minutes).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(model.week.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 6) {
                    Capsule()
                        .fill(day.minutes == 0 ? Color.white.opacity(0.08) : Palette.moon)
                        .frame(height: max(6, 72 * CGFloat(day.minutes) / CGFloat(peak)))
                    Text(day.day, format: .dateTime.weekday(.narrow))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 96, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("stats.week"))
    }

    private var lockedStats: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("stats.title", systemImage: "lock.fill")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Palette.text)
                Text("stats.locked")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                Button {
                    model.showPaywall = true
                } label: {
                    Text("you.upgrade")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("you.upgrade.stats")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.moon, in: Capsule())
            }
        }
    }

    private var proCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.isPro ? "you.pro" : "you.free")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Palette.text)
                if !model.isPro {
                    Button {
                        model.showPaywall = true
                    } label: {
                        Text("you.upgrade")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("you.upgrade.plans")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Palette.moon)
                } else {
                    Link("you.manage", destination: Links.subscriptions)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Palette.moon)
                }
                Button("you.restore") {
                    Task { await model.restorePurchases() }
                }
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Palette.mist)
                if model.restoreNote {
                    Text("you.restored")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                if model.store.errorKey == "paywall.failed" {
                    Text("paywall.failed")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Palette.moon)
                }
            }
        }
    }

    private var notifications: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("you.notifications")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Palette.text)
                Text(notificationCopy)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                if model.notificationOn != true {
                    Button("you.enableNotifications") {
                        Task { await model.enableNotifications() }
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Palette.moon)
                }
            }
        }
    }

    private var notificationCopy: LocalizedStringKey {
        switch model.notificationOn {
        case .some(true): return "you.notificationsOn"
        case .some(false): return "you.notificationsOff"
        case .none: return "you.notificationsUnknown"
        }
    }

    private var about: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("you.about")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Palette.text)
                Text("you.aboutBody")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                Link("you.channel", destination: Links.channel)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Palette.moon)
                HStack(spacing: 16) {
                    Link("paywall.terms", destination: Links.terms)
                    Link("paywall.privacy", destination: Links.privacy)
                }
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Palette.mist)
            }
        }
    }

    private var versionLine: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(L10n.tr("you.version")) \(short) (\(build))"
    }
}
