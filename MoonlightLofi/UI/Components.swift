import SwiftUI

struct PrimaryButton: View {
    var titleKey: String
    var systemImage: String? = nil
    var identifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(LocalizedStringKey(titleKey))
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Palette.moon, in: Capsule())
            .foregroundStyle(Palette.ink)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "")
    }
}

struct IconCircle: View {
    var systemImage: String
    var labelKey: String
    var active: Bool = false
    var prominent: Bool = false
    var identifier: String? = nil
    var value: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(prominent ? .title2 : .body)
                .frame(width: prominent ? 68 : 48, height: prominent ? 68 : 48)
                .foregroundStyle(active || prominent ? Palette.ink : Palette.text)
                .background(active || prominent ? Palette.moon : Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey)))
        .accessibilityIdentifier(identifier ?? "")
        .accessibilityValue(Text(value ?? ""))
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

struct MoonPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Palette.night.ignoresSafeArea()
            HStack {
                Spacer(minLength: 0)
                content
                    .frame(maxWidth: 560)
                Spacer(minLength: 0)
            }
        }
    }
}
