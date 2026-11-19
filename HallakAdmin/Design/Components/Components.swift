import SwiftUI

/// A tappable card on Home: title, big number, a few lines under it.
struct StatCard<Detail: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    var value: String?
    var tint: Color = Theme.ink
    var badge: Int? = nil
    var action: (() -> Void)?
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        Button {
            Haptics.tap()
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .foregroundStyle(Theme.brandRed)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                    Spacer(minLength: 4)
                    if let badge, badge > 0 {
                        Text(verbatim: "\(badge)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.actionRed))
                    }
                    if action != nil {
                        Image(systemName: "chevron.forward")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSecondary.opacity(0.6))
                            .accessibilityHidden(true)
                    }
                }
                if let value {
                    Text(verbatim: value)
                        .font(.statNumber)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .environment(\.layoutDirection, .leftToRight)
                }
                detail()
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(action == nil ? [] : .isButton)
    }
}

extension StatCard where Detail == EmptyView {
    init(title: LocalizedStringKey, systemImage: String, value: String?, tint: Color = Theme.ink, badge: Int? = nil, action: (() -> Void)? = nil) {
        self.init(title: title, systemImage: systemImage, value: value, tint: tint, badge: badge, action: action) { EmptyView() }
    }
}

/// A status pill. Color plus words: status is never shown by color alone.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(verbatim: text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
            .accessibilityLabel(Text(verbatim: text))
    }
}

/// Money as the API sends it (`display`), kept left-to-right inside Arabic text.
struct MoneyText: View {
    let money: Money?
    var body: some View {
        Text(verbatim: money?.display ?? "–")
            .monospacedDigit()
            .environment(\.layoutDirection, .leftToRight)
    }
}

/// "Offline – showing data from 13:13" + Retry.
struct OfflineBanner: View {
    let time: String
    var retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash").accessibilityHidden(true)
            Text("Offline – showing data from \(time)")
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Retry", action: retry)
                .font(.footnote.bold())
                .frame(minHeight: Theme.minTouch)
        }
        .padding(.horizontal, 14)
        .foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.navy))
    }
}

/// "Updated 13:13" in the toolbar.
struct UpdatedLabel: View {
    let generatedAt: String?
    var isLoading = false

    var body: some View {
        HStack(spacing: 6) {
            if isLoading { ProgressView().controlSize(.mini) }
            if let t = Formatters.updatedTime(generatedAt) {
                Text("Updated \(t)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
    }
}

/// Nothing to show yet: the barber waves.
struct EmptyState: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    var image = "BarberWave"

    var body: some View {
        VStack(spacing: 12) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .accessibilityHidden(true)
            Text(title).font(.headline).foregroundStyle(Theme.ink)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Something went wrong and there is nothing saved to show: the stressed barber + Retry.
struct ErrorView: View {
    let error: APIError
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image("BarberStressed")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .accessibilityHidden(true)
            Text(error.userMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)
            if let retry, ![.slowDown, .locked].contains(error.behaviour) {
                Button(action: retry) {
                    Text("Try again").frame(minWidth: 160, minHeight: Theme.minTouch)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.actionRed)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// A screen that comes in a later milestone.
struct ComingSoonView: View {
    let title: LocalizedStringKey
    let milestone: String

    var body: some View {
        ScrollView {
            EmptyState(title: title, message: "This screen comes in the next builds.", image: "BarberHappy")
            Text(verbatim: milestone)
                .font(.caption.monospaced())
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle(title)
    }
}
