# e2ee-notes

A storage-independent, end-to-end encrypted notes application for Android,
iOS, Linux, macOS, and Windows.

This repository starts cleanly from lessons learned in `lab-keybridge` and
`lab-e2ee-notes`; neither prototype's code or wire format is treated as stable.

> This is pre-alpha, unaudited software. Do not use it for sensitive or
> irreplaceable notes.

## Layout

```text
app/                         Flutter application for five platforms
app/lib/crypto/              encrypted data model and operation cipher
app/lib/notes/               notes UI, encrypted operation log and projection
app/lib/vault/               vault initialization and key persistence
app/lib/storage/             blob-store contract and filesystem adapter
app/test/                    application and component tests
packages/secure_keys/        key capabilities and native key adapters
spec/                        versioned protocols and test vectors
docs/                        architecture, threat model, and roadmap
```

Application code lives in responsibility-based folders under `app/lib`.
Extract a package when a stable API and a clear dependency boundary emerge.
`secure_keys` remains separate because it is a native Flutter plugin.

## Development

Enter the reproducible development shell and verify the Flutter packages:

```sh
nix develop
cd app
flutter analyze
flutter test
```

Build an Android debug APK with:

```sh
flutter build apk --debug
```

The APK is written to `app/build/app/outputs/flutter-apk/app-debug.apk`.
Android 11 or later can connect to this headless development machine through
Wireless debugging:

```sh
adb pair DEVICE_ADDRESS:PAIRING_PORT
adb connect DEVICE_ADDRESS:DEBUG_PORT
flutter run -d DEVICE_ID
```

The app stores encrypted immutable operations in the platform's
application-support directory. On Secure Enclave-capable Apple devices, its
vault key is wrapped for a non-exportable P-256 recipient key. Windows and Linux
use TPM 2.0 when available; see [TPM setup and limitations](docs/TPM.md).
Platforms without a supported hardware provider use a software key.

## Deployment

For iOS device and TestFlight distribution, see [Deployment](docs/DEPLOYMENT.md).
