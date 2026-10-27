import SwiftUI
import WebKit

struct BrowserSurface: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// WKUserContentController retains its message handlers. This proxy avoids a cycle.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: InboxBrowser?
    init(target: InboxBrowser) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.received(message)
    }
}

final class InboxBrowser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var webView: WKWebView?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var notice: String?
    private var preparing = false
    private var redirectPending = false

    func clearSession() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView = nil
        isLoading = true
        errorMessage = nil
        notice = nil
        preparing = true
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            DispatchQueue.main.async {
                self?.preparing = false
                self?.isLoading = false
            }
        }
    }

    func start() {
        if let webView {
            errorMessage = nil
            webView.load(URLRequest(url: NavigationPolicy.inbox))
            return
        }
        guard !preparing else { return }
        preparing = true
        isLoading = true
        errorMessage = nil
        guard let policyURL = Bundle.main.url(forResource: "navigation-policy", withExtension: "js"),
              let guardURL = Bundle.main.url(forResource: "inbox-guard", withExtension: "js"),
              let policy = try? String(contentsOf: policyURL, encoding: .utf8),
              let guardScript = try? String(contentsOf: guardURL, encoding: .utf8),
              let rulesURL = Bundle.main.url(forResource: "media-rules", withExtension: "json"),
              let rules = try? String(contentsOf: rulesURL, encoding: .utf8) else {
            fail("The blocking resources are missing. Rebuild the app with all bundled resources.")
            return
        }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "InboxStage2Media", encodedContentRuleList: rules) { [weak self] ruleList, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard error == nil, let ruleList else {
                    self.fail("The media blocker could not start. Instagram has not been opened.")
                    return
                }
                let configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = .default()
                configuration.mediaTypesRequiringUserActionForPlayback = .all
                configuration.allowsInlineMediaPlayback = false
                configuration.allowsPictureInPictureMediaPlayback = false
                let controller = configuration.userContentController
                controller.add(ruleList)
                controller.add(WeakMessageHandler(target: self), name: "inboxGuard")
                controller.addUserScript(WKUserScript(source: policy + "\n" + guardScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
                let view = WKWebView(frame: .zero, configuration: configuration)
                view.navigationDelegate = self
                view.uiDelegate = self
                view.allowsBackForwardNavigationGestures = false
                view.allowsLinkPreview = false
                self.webView = view
                self.preparing = false
                view.load(URLRequest(url: NavigationPolicy.inbox))
            }
        }
    }

    func openInbox() {
        errorMessage = nil
        webView?.load(URLRequest(url: NavigationPolicy.inbox))
    }

    private func fail(_ message: String) {
        preparing = false
        isLoading = false
        errorMessage = message
    }

    private func blocked() {
        // A denied auxiliary action must not destroy the user's sign-in form.
        // They can explicitly request the inbox after completing authentication.
        if NavigationPolicy.isAuthentication(webView?.url) {
            notice = "A navigation was blocked during sign-in. Your login page has been kept open. Finish signing in, then tap Inbox if needed. Facebook sign-in is not supported in this prototype."
            return
        }
        notice = "This content may contain videos and is blocked. Ask your friend to send a photo or text instead."
        guard !redirectPending else { return }
        redirectPending = true
        // Defer until the navigation decision callback has completed.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.redirectPending = false
            guard !NavigationPolicy.isAuthentication(self.webView?.url) else { return }
            if self.webView?.url?.path != NavigationPolicy.inbox.path {
                self.openInbox()
            }
        }
    }

    func received(_ message: WKScriptMessage) {
        guard message.name == "inboxGuard",
              ["instagram.com", "www.instagram.com"].contains(message.frameInfo.securityOrigin.host),
              let body = message.body as? String else { return }
        // No account data, URLs, passwords or message contents cross this bridge.
        if body == "blocked" { blocked() }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let authSubframe = NavigationPolicy.allowsAuthenticationSubframe(navigationAction.request.url, parent: webView.url, isMainFrame: navigationAction.targetFrame?.isMainFrame != false)
        guard !navigationAction.shouldPerformDownload,
              NavigationPolicy.allows(navigationAction.request.url) || authSubframe else {
            decisionHandler(.cancel)
            // A rejected subframe must not repeatedly reload the top-level inbox.
            if navigationAction.targetFrame?.isMainFrame != false { blocked() }
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let authSubframe = NavigationPolicy.allowsAuthenticationSubframe(navigationResponse.response.url, parent: webView.url, isMainFrame: navigationResponse.isForMainFrame)
        guard navigationResponse.canShowMIMEType,
              NavigationPolicy.allows(navigationResponse.response.url) || authSubframe,
              navigationResponse.response.mimeType == "text/html" else {
            decisionHandler(.cancel)
            if navigationResponse.isForMainFrame { blocked() }
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // No popups, Safari handoff or external app/deep-link launches.
        if NavigationPolicy.allows(navigationAction.request.url) {
            webView.load(navigationAction.request)
        } else { blocked() }
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard NavigationPolicy.allows(webView.url) else { blocked(); return }
        // Keep the page covered if injection failed instead of displaying it unfiltered.
        webView.evaluateJavaScript("window.__inboxGuardReady === true") { [weak self] result, error in
            guard let self else { return }
            if error != nil || (result as? Bool) != true {
                self.fail("The page filter could not be verified. The page is hidden. Retry to open the inbox.")
            } else { self.isLoading = false }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { handle(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { handle(error) }
    private func handle(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        fail("Instagram could not load. Check your connection and retry. Some sign-in flows may not yet be supported.")
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        fail("The browser stopped. Retry to reopen the protected inbox.")
    }
}
