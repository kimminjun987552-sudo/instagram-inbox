# Instagram Inbox — experimental iPhone beta

Native SwiftUI/WKWebView browser with inbox-first navigation and restrictions on public media. Not affiliated with Instagram or Meta.

## Build without Xcode on your computer
Open **Actions → Build iPhone beta → Run workflow**. After a successful run, download **InstagramInbox-AltStore** from Artifacts and extract the ZIP to get the IPA. AltStore Classic must sign/install this file with your own Apple account. No Apple credentials or certificates are needed in GitHub. Standard macOS Actions runners in public repositories are free; the artifact expires after 7 days.

This is an unsigned IPA for sideloading, not an App Store/TestFlight release or a Safari-installable app. Free-account installations need refreshing every 7 days. No paid Apple Developer membership is used by this workflow.

## Status and privacy
Requires an iPhone supporting iOS 18 or later. iPhone X is not supported. iPhone build, login, messaging and blocking are not yet verified on a device. Mac testing does not establish iPhone compatibility. Text messaging is the first target; voice/calls and full photo-upload behavior are not supported or verified. Blocking may break when Instagram changes.

Login occurs on Instagram's website. This source has no app backend or analytics SDK. WebKit stores the session locally; Clear session removes this app's website data. Meta and its verification providers still receive website traffic. See native-ios/BETA-PRIVACY.md for source review and remaining device checks.

Never upload Apple passwords, signing certificates, Instagram sessions, logs or personal files to this repository.
