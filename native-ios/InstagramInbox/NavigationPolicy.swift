import Foundation

/// Stage 2 deliberately allows only authentication and existing DM conversations.
enum NavigationPolicy {
    static let inbox = URL(string: "https://www.instagram.com/direct/inbox/")!

    static func isAuthentication(_ url: URL?) -> Bool {
        guard allows(url), let path = url?.path else { return false }
        return path.hasPrefix("/accounts/") || path.hasPrefix("/challenge") || path == "/auth_platform" || path.hasPrefix("/auth_platform/")
    }

    static func allowsAuthenticationSubframe(_ url: URL?, parent: URL?, isMainFrame: Bool) -> Bool {
        guard !isMainFrame, isAuthentication(parent), let url else { return false }
        if url.absoluteString == "about:blank" { return true }
        if url.scheme == "https", ["www.instagram.com", "instagram.com"].contains(url.host?.lowercased() ?? ""),
           url.user == nil, url.password == nil, url.port == nil || url.port == 443,
           url.path == "/common/referer_frame.php" { return true }
        if url.scheme == "https", url.host?.lowercased() == "www.fbsbx.com",
           url.user == nil, url.password == nil, url.port == nil || url.port == 443,
           ["/captcha/recaptcha/iframe", "/captcha/recaptcha/iframe/"].contains(url.path) { return true }
        guard url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443,
              ["www.google.com", "recaptcha.google.com", "www.recaptcha.net"].contains(url.host?.lowercased() ?? "") else { return false }
        return url.path.hasPrefix("/recaptcha/")
    }

    static func allows(_ url: URL?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              ["www.instagram.com", "instagram.com"].contains(host),
              url.port == nil || url.port == 443,
              url.user == nil, url.password == nil else { return false }
        // Reject encoded separators and traversal before matching an exact route.
        let path = url.path
        guard !path.contains("%"), !path.contains("\\"),
              !path.split(separator: "/", omittingEmptySubsequences: false).contains("..") else { return false }
        let patterns = [
            "^/direct/inbox/?$",
            "^/direct/new/?$",
            "^/direct/t/[A-Za-z0-9_-]+/?$",
            "^/accounts/login/?$",
            "^/accounts/login/two_factor/?$",
            "^/accounts/onetap/?$",
            "^/auth_platform/?$",
            "^/auth_platform/(?:recaptcha|codeentry)/?$",
            "^/challenge(?:/[A-Za-z0-9_-]+)*/?$"
        ]
        return patterns.contains { path.range(of: $0, options: .regularExpression) != nil }
    }
}
