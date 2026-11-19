# Hallak Admin (iPhone)

Native SwiftUI app for the Hallak super admin, connected to the Hallak admin API 1.0.1
(`{site}/wp-json/hallak/v1/admin/...`). Spec: [docs/HALLAK-APP-BRIEF.pdf](docs/HALLAK-APP-BRIEF.pdf) and
[docs/hallak-api.yaml](docs/hallak-api.yaml).

iOS 17+, Swift / SwiftUI, no third-party packages. English + Arabic (RTL).

## Status

| Milestone | What | State |
| --- | --- | --- |
| M1 | Project, API client, models, tests, CI | done |
| M2 | Login, Keychain, Face ID, Home | done |
| M3 | Salons | done |
| M4 | Money and Requests | done |
| M5 | More | done |
| M6 | Polish and Arabic | done (check on the phone for a week) |

## Layout

```
HallakAdmin/
  App/            HallakAdminApp, RootView
  Core/API/       APIClient (actor), Endpoint (all 18), APIError (section 4 mapping), ETagCache
  Core/Models/    Money, Paging, Connection (ping, me, features), Overview, Salon, Billing, Invoice,
                  Plan, Lead, Activity, Health, WhatsApp, AI
  Core/Security/  Keychain
  Core/Util/      Formatters (Lebanon time, as sent), Haptics
  Design/         Theme (brief colors, light + dark)
  Resources/      Assets.xcassets (icon, logo, barber, colors), Localizable.xcstrings (en, ar)
HallakAdminTests/ JSON fixtures for every endpoint + tests
scripts/          make_fixtures.py (test answers), strings.py (en + ar catalogs), check_strings.py, pick_simulator.sh (CI)
fastlane/         Fastfile: tests, beta (TestFlight)
.github/workflows/ios.yml
```

## Build (from Windows: GitHub Actions does it)

Every push to `main` runs `.github/workflows/ios.yml` on a cloud Mac:

1. `xcodegen generate` (the Xcode project is generated, not committed)
2. unit tests on the newest iPhone simulator
3. screenshots of every screen (English, Arabic, dark, largest text) in **demo mode**, as an artifact.
   Demo mode exists only in Debug builds: `-HallakDemo YES` makes the app read `HallakAdmin/DemoData`
   (the test answers) instead of the network. The Release IPA leaves DemoData out.
4. **unsigned IPA** `HallakAdmin-unsigned.ipa`, as an artifact (install with Sideloadly / AltStore, which
   sign it with your Apple ID)
5. **TestFlight** upload, only when these repository secrets exist:
   - `ASC_KEY_ID`, `ASC_ISSUER_ID`: App Store Connect API key (Users and Access → Integrations)
   - `ASC_KEY_P8`: the .p8 file in base64 (`base64 -w0 AuthKey_XXXX.p8`)
   - `APPLE_TEAM_ID`: your 10-character Team ID
   - plus, in App Store Connect: App ID `online.hallak.admin` and an app named "Hallak Admin"

Download the latest IPA from Windows:

```bash
gh run download --name HallakAdmin-ipa --dir dist
```

On a Mac: `brew install xcodegen && xcodegen generate && open HallakAdmin.xcodeproj`.

## Rules kept in code

- Login only in the Keychain (`AfterFirstUnlockThisDeviceOnly`), HTTPS only, no secrets in code.
- Lebanon times are shown as sent, never converted from UTC.
- Money: show `display`, sort by `amount`.
- Unknown JSON fields are ignored; missing sections hide their card.
- 401 and 429 are never retried.
