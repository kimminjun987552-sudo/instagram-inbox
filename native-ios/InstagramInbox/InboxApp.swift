import SwiftUI

@main
struct InboxApp: App {
    var body: some Scene {
        WindowGroup { InboxView() }
    }
}

struct InboxView: View {
    @StateObject private var browser = InboxBrowser()
    @State private var started = false
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "tray.fill")
                Text("Instagram Inbox").font(.headline)
                Spacer()
                if started {
                    Button("Inbox") { browser.openInbox() }
                    Button { confirmReset = true } label: {
                        Image(systemName: "trash").accessibilityLabel("Clear Instagram session")
                    }.disabled(browser.isLoading)
                }
            }
            .padding()
            .background(Color(red: 0.93, green: 0.96, blue: 0.91))

            if !started {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 48))
                    Text("Keep the people.\nLeave the feed.")
                        .font(.largeTitle.weight(.semibold))
                    Text("An experimental inbox-only browser for Instagram.")
                    Text("Private beta candidate. Start with text messages. Videos, shared links, feeds, search, profiles and posting are restricted. Voice and calls are unavailable. iPhone compatibility and complete blocking still need testing.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Sign in only on Instagram’s own page. This app has no password form and no server that receives your login or messages.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Open Instagram inbox") {
                        started = true
                        browser.start()
                    }.buttonStyle(.borderedProminent).tint(.init(red: 0.25, green: 0.39, blue: 0.23)).disabled(browser.isLoading)
                    Spacer()
                }.padding(28)
            } else {
                ZStack {
                    if let webView = browser.webView {
                        BrowserSurface(webView: webView)
                    }
                    if let error = browser.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.bubble")
                            Text(error).multilineTextAlignment(.center)
                            Button("Retry inbox") { browser.start() }
                        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.background)
                    } else if browser.isLoading {
                        ProgressView("Opening inbox…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.background)
                    }
                }
            }

            if let notice = browser.notice {
                HStack(alignment: .top) {
                    Image(systemName: "hand.raised.fill")
                    Text(notice).font(.footnote)
                    Button { browser.notice = nil } label: {
                        Image(systemName: "xmark").accessibilityLabel("Dismiss notice")
                    }
                }.padding().background(Color(red: 0.93, green: 0.96, blue: 0.91))
            }
            Text("Private beta · Inbox only")
                .font(.caption2).foregroundStyle(.secondary).padding(8)
        }
        .confirmationDialog("Clear the saved Instagram session on this device?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Clear session", role: .destructive) {
                browser.clearSession()
                started = false
            }
        } message: {
            Text("Removes this app’s cookies and website cache. Your Instagram account and messages are not deleted.")
        }
    }
}
