import SafariServices
import SwiftUI

/// Call / WhatsApp / mail buttons. WhatsApp only through the one-tap wa.me link from the API.
enum Contact {
    static func phoneURL(_ phone: String?) -> URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard digits.count >= 6 else { return nil }
        return URL(string: "tel:\(digits)")
    }

    static func mailURL(_ email: String?) -> URL? {
        guard let email, email.contains("@") else { return nil }
        return URL(string: "mailto:\(email)")
    }

    /// Only https://wa.me/... links sent by the API (never built in the app).
    static func whatsappURL(_ link: String?) -> URL? {
        guard let link, let url = URL(string: link), url.scheme == "https",
              let host = url.host, host == "wa.me" || host.hasSuffix("whatsapp.com") else { return nil }
        return url
    }

    static func webURL(_ link: String?) -> URL? {
        guard let link, let url = URL(string: link), url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }
}

/// A round icon button (44 pt).
struct ContactButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let url: URL?
    /// Ink = navy in light mode, cream in dark mode (navy would vanish on the dark background).
    var tint: Color = Theme.ink
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url {
            Button {
                Haptics.tap()
                openURL(url)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(tint.opacity(0.12)))
                    Text(title).font(.caption2)
                }
                .foregroundStyle(tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title))
        }
    }
}

/// Safari inside the app (dashboard, salon page, booking page).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(named: "ActionRed")
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

/// A simple "label → value" row; value kept left-to-right for numbers and dates.
struct InfoRow: View {
    let label: LocalizedStringKey
    let value: String?
    var valueColor: Color = Theme.ink

    var body: some View {
        if let value, !value.isEmpty {
            LabeledContent {
                Text(verbatim: value)
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            } label: {
                Text(label)
            }
        }
    }
}

/// On/off with words (never color alone).
struct OnOffRow: View {
    let label: LocalizedStringKey
    let isOn: Bool?

    var body: some View {
        if let isOn {
            LabeledContent {
                Label(isOn ? "On" : "Off", systemImage: isOn ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(isOn ? Theme.green : Theme.grey)
            } label: {
                Text(label)
            }
        }
    }
}
