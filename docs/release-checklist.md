# Echo release checklist

## Automated in the repository

- Marketing version: `1.1`
- Build number: `2026090501`
- Bundle identifier: `com.bambi2008.Echo`
- Apple team: `4V982CAJ45`
- iPhone and iPad targets enabled
- Privacy manifest included with no tracking and the app-scoped UserDefaults reason
- Contacts, microphone, and speech-recognition permission explanations included
- Store failures show a non-destructive recovery screen instead of deleting data or crashing
- External Gmail delivery requires a reviewed draft and explicit confirmation

## App Store Connect — requires account access

- Confirm version `1.1` exists for bundle identifier `com.bambi2008.Echo`.
- Create or verify auto-renewable subscriptions:
  - `com.bambi2008.echo.ai.pro.monthly`
  - `com.bambi2008.echo.ai.pro.annual`
- Put both products in the same subscription group and configure a seven-day free introductory offer.
- Add localized product names, prices, review screenshots, subscription terms, Privacy Policy URL, and Terms of Use URL.
- Complete App Privacy answers so they agree with `PrivacyInfo.xcprivacy` and actual DeepSeek/Google behavior.
- Archive with the Release configuration, validate the archive, then upload build `2026090501`.

## Google Cloud — requires account access

- Enable Gmail API and People API for the OAuth project used by the iOS client.
- Add the exact scopes requested by the app: Gmail metadata, Gmail send, contacts readonly, and other contacts readonly.
- Keep the app in Testing while using named test accounts only.
- Before public distribution, configure the app name/logo, support email, authorized domain, homepage, Privacy Policy, Terms of Service, scope explanations, and verification demonstration.
- Submit sensitive-scope verification before moving the OAuth app to Production.

## Real-device release smoke test

1. Install over the previous Echo build; do not delete the existing app.
2. Confirm existing contacts, notes, Gmail history, relationship intentions, and Pipeline items remain present.
3. Confirm API Key shows `Configured`, then run `Test connection`.
4. Disconnect and reconnect Google so the account grants the Gmail send scope.
5. Import Google contacts and sync Gmail history.
6. Draft an email to an address controlled by the tester, inspect it, confirm Send once, and verify exactly one outbound Interaction is recorded.
7. Test monthly and annual sandbox purchases, restore purchases, cancellation, expiration, and trial conversion.
8. Check portrait and landscape on iPhone and iPad, VoiceOver labels, and Dynamic Type at an accessibility size.
