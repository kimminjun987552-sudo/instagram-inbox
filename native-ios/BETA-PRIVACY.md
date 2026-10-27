# iPhone private beta preparation — 2026-10-27

Status: SOURCE ONLY. No iOS binary has been built, signed, installed, or released.

## Source privacy review
- Reviewed InboxApp.swift, InboxBrowser.swift and the injected inbox-guard.js.
- No app backend, advertising SDK, analytics SDK, password form, or message logging is present in these files.
- Instagram runs inside WKWebView and receives login, messages and ordinary website requests directly. Instagram/Meta and its verification providers still process data under their own policies; this is not a claim that the website collects no data.
- WebKit retains login cookies and website storage locally. Added a confirmed Clear session control to remove this app's WebKit data; it does not delete the Instagram account or remote messages.
- The native bridge accepts only the fixed blocked event. No diagnostic handler is registered in the iOS app.
- No camera/microphone permission or background collection is configured. Voice/calls remain unsupported. iOS upload behavior is not verified.
- Source review only: real-device traffic, session deletion, permission prompts, and final signed binary review remain pending before wider beta distribution.

## Smallest next step
Use another Mac with Xcode (or an authorized cloud macOS build environment). Open InstagramInbox.xcodeproj, select InstagramInbox and a connected iPhone running iOS 18+, select your signing team and a unique bundle identifier, then Run. A simulator runtime is not required to build for a physical iPhone.

A free Personal Team supports personal-device testing through Xcode with expiring provisioning. A TestFlight invitation requires Apple Developer Program membership, a signed uploaded build, App Store Connect setup and applicable beta review. No account or remote builder has been connected for this project. An unsigned source ZIP is not an iPhone installer.

## Revised order requested by the user
1. Complete source privacy preparation and obtain an iOS build/signing environment.
2. Install a private iPhone beta and validate login, inbox and essential blocking on the device.
3. Iterate on broader blocking coverage and allowed features after private testing.
4. Complete device privacy/reliability checks before wider release.

Official references:
https://developer.apple.com/help/account/basics/about-your-developer-account
https://developer.apple.com/testflight/
