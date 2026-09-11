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
packages/e2ee_core/          platform-neutral encrypted data model
packages/notes_repository/   encrypted operation log and note projection
packages/storage_api/        minimal blob-store contract
packages/storage_filesystem/ first local storage adapter
packages/hardware_keys/      federated native hardware-key plugin
spec/                        versioned protocols and test vectors
docs/                        architecture, threat model, and roadmap
```

## Development

```sh
nix shell nixpkgs#flutter
cd app
flutter analyze
flutter test
flutter run -d macos
```

The app stores encrypted immutable operations in the platform's
application-support directory. On Secure Enclave-capable Apple devices, its
vault key is wrapped for a non-exportable P-256 recipient key. Windows and Linux
use TPM 2.0 when available; see [TPM setup and limitations](docs/TPM.md).
Platforms without a supported hardware provider use a software key.
