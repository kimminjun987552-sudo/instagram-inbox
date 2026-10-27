import Foundation

@main
struct PolicyTests {
    struct Case: Decodable { let url: String; let allowed: Bool }
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let cases = try JSONDecoder().decode([Case].self, from: data)
        var failures = 0
        for test in cases {
            if NavigationPolicy.allows(URL(string: test.url)) != test.allowed {
                print("FAIL: \(test.url)")
                failures += 1
            }
        }
        precondition(!NavigationPolicy.allows(nil))
        precondition(NavigationPolicy.isAuthentication(URL(string: "https://www.instagram.com/accounts/login/")))
        precondition(NavigationPolicy.isAuthentication(URL(string: "https://www.instagram.com/accounts/onetap/")))
        precondition(!NavigationPolicy.isAuthentication(NavigationPolicy.inbox))
        precondition(!NavigationPolicy.isAuthentication(URL(string: "https://evil.example/accounts/login/")))
        precondition(NavigationPolicy.isAuthentication(URL(string: "https://www.instagram.com/auth_platform")))
        let blank = URL(string: "about:blank")
        let login = URL(string: "https://www.instagram.com/accounts/login/")
        precondition(NavigationPolicy.allowsAuthenticationSubframe(blank, parent: login, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(blank, parent: login, isMainFrame: true))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(blank, parent: NavigationPolicy.inbox, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(URL(string: "https://evil.example/"), parent: login, isMainFrame: false))
        let captcha = URL(string: "https://www.google.com/recaptcha/api2/anchor?k=sample")
        precondition(NavigationPolicy.allowsAuthenticationSubframe(captcha, parent: login, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(captcha, parent: login, isMainFrame: true))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(captcha, parent: NavigationPolicy.inbox, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(URL(string: "https://www.google.com/search"), parent: login, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(URL(string: "https://www.google.com.evil.example/recaptcha/"), parent: login, isMainFrame: false))
        let wrapper = URL(string: "https://www.instagram.com/common/referer_frame.php?sample=1")
        precondition(NavigationPolicy.allowsAuthenticationSubframe(wrapper, parent: login, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(wrapper, parent: login, isMainFrame: true))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(wrapper, parent: NavigationPolicy.inbox, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(URL(string: "https://www.instagram.com/common/reels.php"), parent: login, isMainFrame: false))
        let metaFrame = URL(string: "https://www.fbsbx.com/captcha/recaptcha/iframe/?sample=1")
        precondition(NavigationPolicy.allowsAuthenticationSubframe(metaFrame, parent: login, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(metaFrame, parent: login, isMainFrame: true))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(metaFrame, parent: NavigationPolicy.inbox, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(URL(string: "https://www.fbsbx.com/other/"), parent: login, isMainFrame: false))
        precondition(!NavigationPolicy.allowsAuthenticationSubframe(URL(string: "https://www.fbsbx.com.evil.example/captcha/recaptcha/iframe/"), parent: login, isMainFrame: false))
        guard failures == 0 else { exit(1) }
        print("PASS: \(cases.count) native Swift URL cases and nil URL")
    }
}
