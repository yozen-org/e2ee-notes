# Deployment

How to build and distribute the iOS app to a device: both for quick local
iteration and for TestFlight distribution. Written to be reusable for other
iOS projects on the same build machine.

## Environment

| Item | Value |
|---|---|
| Build machine | `macmini` (SSH, host alias `macmini`, user `fujis`) |
| Flutter | 3.47.4 (Homebrew cask) at `/opt/homebrew/bin/flutter` |
| Xcode | 26.6 |
| Dependency manager | Swift Package Manager (default in Flutter; no CocoaPods) |
| Apple Developer team | Yozen, Team ID `DKR8BM8U9N` |
| App bundle ID | `org.yozen.e2eedocs` |
| App Store Connect SKU | `e2eedocs` |
| Test device | iPad mini (6th gen), UDID `00008110-001679203A44801E` |

## Secrets

The following are stored on the build machine only and must never be committed:

- App Store Connect API key (`.p8` private key): `~/AuthKey_UM2WX5N59Q.p8`
  - Key ID: `UM2WX5N59Q`, Issuer ID: `ae3519e6-812c-479f-a7b9-98ccbed8f101`
- login keychain password (required for code signing over SSH)

The API key's Issuer ID and Key ID are identifiers, not secrets; the `.p8`
private key is the secret.

## Source sync

The git repository is the source of truth. The build machine keeps a working
copy at `~/ws/e2ee-notes`. Sync uncommitted changes with:

```sh
rsync -az --exclude '.git' --exclude '.dart_tool' --exclude 'build' \
  --exclude '.idea' --exclude '.vscode' --exclude 'Pods' \
  /path/to/e2ee-notes/ macmini:~/ws/e2ee-notes/
```

## Signing configuration in the project

iOS signing is configured in `app/ios/Runner.xcodeproj/project.pbxproj`
(Runner target, Debug/Release/Profile):

- `PRODUCT_BUNDLE_IDENTIFIER = org.yozen.e2eedocs`
- `DEVELOPMENT_TEAM = DKR8BM8U9N`
- `CODE_SIGN_STYLE = Automatic`

`CODE_SIGN_STYLE = Automatic` is required. Without it, the archive resolves to
`CODE_SIGN_IDENTITY = iPhone Developer` (development signing) and fails to
produce an App Store build.

## Code signing over SSH

SSH sessions start with the login keychain locked, so `codesign` fails with
`errSecInternalComponent` or `User interaction is not allowed`. Unlock the
keychain before every build, in the same SSH session:

```sh
security unlock-keychain -p "$KEYCHAIN_PASSWORD" ~/Library/Keychains/login.keychain-db
```

## Path A: direct device install (quick iteration)

Use this when the device is reachable via USB or the same LAN as `macmini`.
Requires only a development signing identity (no App Store Connect needed).

```sh
export PATH="/opt/homebrew/bin:$PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" ~/Library/Keychains/login.keychain-db
cd ~/ws/e2ee-notes/app
flutter build ios --profile
xcrun devicectl device install app --device "$UDID" build/ios/iphoneos/Runner.app
```

Notes:

- Use `--profile` (or `--release`), not `--debug`: on iOS 14+ a debug build
  cannot be launched from the home screen.
- `xcrun devicectl list devices` shows reachability; the device must be
  `available (paired)`.
- `devicectl` uses USB / local Bonjour / iCloud remote only. **It does not
  discover devices over Tailscale.** Keep the device on USB or the same Wi-Fi.

## Path B: TestFlight (App Store distribution)

Use this for testing away from home or for distributing to several testers.
Requires a paid Apple Developer membership.

### One-time prerequisites

1. Paid Apple Developer team (here: Yozen, `DKR8BM8U9N`).
2. Register the app in App Store Connect with a unique bundle ID and an
   arbitrary SKU (here: `org.yozen.e2eedocs` / `e2eedocs`). No capabilities are
   needed for this app.
3. Create an App Store Connect API key (Users and Access > Integrations) with
   the App Manager role. Save the `.p8` on the build machine.
4. Register at least one device UDID on the team. Automatic signing refuses to
   create profiles for a team with zero devices ("Your team has no devices from
   which to generate a provisioning profile"). Register via the API:

   ```sh
   JWT=$(xcrun altool --generate-jwt --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID" \
     --p8-file-path "$P8" 2>&1 | grep -oE 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+')
   curl -s -X POST "https://api.appstoreconnect.apple.com/v1/devices" \
     -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
     -d '{"data":{"type":"devices","attributes":{"name":"iPad mini","platform":"IOS","udid":"'"$UDID"'"}}}'
   ```

### Build and upload

Each upload needs a unique version/build. Bump `version` in `pubspec.yaml`
(e.g. `1.0.0+4`) before building.

```sh
export PATH="/opt/homebrew/bin:$PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" ~/Library/Keychains/login.keychain-db
cd ~/ws/e2ee-notes/app
flutter build ipa
xcrun altool --upload-app --type ios -f build/ios/ipa/e2ee_notes.ipa \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID" --p8-file-path "$P8"
```

`flutter build ipa` archives with automatic signing (creating the
Apple Distribution certificate and App Store profile on first use) and exports
an `.ipa`. `altool` uploads it with the API key.

### TestFlight testing

1. In App Store Connect > the app > TestFlight, wait for the build to reach
   "Ready to Test".
2. Add internal testers (Testers & Groups > App Store Connect Users).
3. Install the TestFlight app on the device, sign in with the same Apple ID,
   and install the build. Internal testers require no beta review.

## Export compliance

To avoid the App Store Connect export-compliance questionnaire on every
upload, declare the app's encryption use in `app/ios/Runner/Info.plist`:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

`false` declares "uses only exempt encryption", which is correct for this
local-only notes app (data-at-rest encryption, no communications crypto). An
app that ships non-exempt encryption would need documentation instead.

## Gotchas

- **Zero-device team**: automatic signing fails to create profiles until at
  least one device is registered (see prerequisites above).
- **Stale Flutter paths**: do not run `xcodebuild` directly on a project synced
  from another machine; the generated `ios/Flutter` files carry the source
  machine's SDK path. Always build through `flutter build`.
- **SPM vs CocoaPods**: Flutter 3.47 uses Swift Package Manager by default.
  Plugins with a `Package.swift` need no CocoaPods.
- **Device locked/asleep**: `devicectl` reports `unavailable` when the device
  is locked or disconnected; wake and unlock it, or reconnect USB.
