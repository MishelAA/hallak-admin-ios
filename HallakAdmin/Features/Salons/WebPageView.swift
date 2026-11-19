import SwiftUI
import WebKit

/// A web page shown inside the app (salon dashboard, salon page, booking page), pushed like any screen.
/// For a salon dashboard (`signInSalonId`), the app first asks the site for a one-time sign-in link
/// (plugin salon-manager-app-login), so the dashboard opens signed in as you.
/// Links inside the page stay here; phone, WhatsApp and mail links open their apps.
struct WebPageView: View {
    let url: URL
    let title: String
    var signInSalonId: Int?

    @Environment(AppSession.self) private var session
    @State private var model = WebPageModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        WebView(model: model)
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    if model.progress < 1 {
                        ProgressView(value: model.progress)
                            .tint(Theme.actionRed)
                            .progressViewStyle(.linear)
                    }
                    if let notice = model.notice {
                        Label { Text(verbatim: notice) } icon: { Image(systemName: "info.circle.fill") }
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.navy)
                    }
                }
            }
            .overlay {
                if model.isSigningIn {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Signing in to the dashboard…").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
                } else if let error = model.error {
                    VStack(spacing: 14) {
                        Image("BarberStressed").resizable().scaledToFit().frame(height: 140).accessibilityHidden(true)
                        Text("The page did not open.").font(.headline)
                        Text(verbatim: error).font(.footnote).foregroundStyle(Theme.inkSecondary).multilineTextAlignment(.center)
                        Button {
                            Task { await start() }
                        } label: {
                            Text("Try again").frame(minWidth: 160, minHeight: Theme.minTouch)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.actionRed)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
                }
            }
            .navigationTitle(Text(verbatim: model.pageTitle ?? title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { model.goBack() } label: { Image(systemName: "chevron.backward") }
                        .disabled(!model.canGoBack)
                        .accessibilityLabel(Text("Back"))
                    Button { model.goForward() } label: { Image(systemName: "chevron.forward") }
                        .disabled(!model.canGoForward)
                        .accessibilityLabel(Text("Forward"))
                    Spacer()
                    Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel(Text("Reload"))
                    if let current = model.currentURL, current.query?.contains("hallak_app_login") != true {
                        ShareLink(item: current) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel(Text("Share"))
                    }
                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
            .toolbar(.hidden, for: .tabBar)
            .onAppear { model.openExternal = { openURL($0) } }
            .task { if !model.started { await start() } }
    }

    /// Plain pages load at once. Dashboards ask for the one-time sign-in link first.
    private func start() async {
        model.started = true
        model.error = nil
        guard let salonId = signInSalonId, let client = session.client else {
            model.load(url)
            return
        }
        model.isSigningIn = true
        defer { model.isSigningIn = false }
        do {
            let answer = try await client.send(.webLogin(salonId: salonId), as: WebLoginAnswer.self)
            if let link = answer.safeURL(site: client.credentials.site) {
                model.notice = nil
                model.load(link)
            } else {
                model.notice = String(localized: "The site sent a sign-in link for another address, so the dashboard opened without it.")
                model.load(url)
            }
        } catch let e as APIError {
            if await session.handleSessionError(e) { return }
            if e.status == 404 && (e.code == "rest_no_route" || e.code == "smapi_no_core") {
                // The site does not have the App Login plugin yet: open the page as it is.
                model.notice = String(localized: "To open dashboards signed in, install the “Salon Manager – App Login” plugin on the site.")
                model.load(url)
            } else {
                model.error = e.userMessage
            }
        } catch {
            model.error = APIError.offline.userMessage
        }
    }
}

/// State of the page: progress, title, back / forward.
@Observable
@MainActor
final class WebPageModel {
    var progress: Double = 1
    var pageTitle: String?
    var canGoBack = false
    var canGoForward = false
    var currentURL: URL?
    var error: String?
    var notice: String?
    var isSigningIn = false
    var started = false
    var openExternal: ((URL) -> Void)?
    /// A page asked for before the web view exists.
    var pendingURL: URL?
    weak var webView: WKWebView?

    func load(_ url: URL) {
        error = nil
        currentURL = url
        if let webView {
            webView.load(URLRequest(url: url))
        } else {
            pendingURL = url
        }
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }

    func reload() {
        error = nil
        if webView?.url == nil, let u = currentURL { webView?.load(URLRequest(url: u)) } else { webView?.reload() }
    }
}

struct WebView: UIViewRepresentable {
    let model: WebPageModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Shared with the other in-app pages, so one sign-in covers every salon dashboard.
        config.websiteDataStore = .default()
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.backgroundColor = UIColor(named: "Cream")
        web.isOpaque = false
        context.coordinator.observe(web)
        model.webView = web
        if let pending = model.pendingURL {
            model.pendingURL = nil
            web.load(URLRequest(url: pending))
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        coordinator.observations.removeAll()
        web.stopLoading()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let model: WebPageModel
        var observations: [NSKeyValueObservation] = []

        init(model: WebPageModel) { self.model = model }

        func observe(_ web: WKWebView) {
            observations = [
                web.observe(\.estimatedProgress, options: [.new]) { [weak self] w, _ in
                    let p = w.estimatedProgress
                    Task { @MainActor in self?.model.progress = p }
                },
                web.observe(\.title, options: [.new]) { [weak self] w, _ in
                    let t = w.title
                    Task { @MainActor in self?.model.pageTitle = (t?.isEmpty == false) ? t : nil }
                },
                web.observe(\.canGoBack, options: [.new]) { [weak self] w, _ in
                    let b = w.canGoBack
                    Task { @MainActor in self?.model.canGoBack = b }
                },
                web.observe(\.canGoForward, options: [.new]) { [weak self] w, _ in
                    let f = w.canGoForward
                    Task { @MainActor in self?.model.canGoForward = f }
                },
                web.observe(\.url, options: [.new]) { [weak self] w, _ in
                    let u = w.url
                    Task { @MainActor in if let u { self?.model.currentURL = u } }
                },
            ]
        }

        /// Web pages stay in the app; phone, WhatsApp, mail and app links open outside.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .cancel }
            let scheme = url.scheme?.lowercased() ?? ""
            let host = url.host?.lowercased() ?? ""
            let isWhatsApp = host == "wa.me" || host.hasSuffix("whatsapp.com")
            let isWeb = ["http", "https", "about", "blob", "data"].contains(scheme)
            if isWeb && !isWhatsApp { return .allow }
            model.openExternal?(url)
            return .cancel
        }

        /// target="_blank" links open in the same screen.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if action.targetFrame == nil { webView.load(action.request) }
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.error = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            show(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            show(error)
        }

        private func show(_ error: Error) {
            let e = error as NSError
            // Cancelled loads (a new link tapped, or handed to another app) are not errors.
            if e.code == NSURLErrorCancelled || e.domain == "WebKitErrorDomain" { return }
            model.error = e.localizedDescription
            model.progress = 1
        }
    }
}
