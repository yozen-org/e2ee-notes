# Roadmap

## M0 — foundation

- Flutter scaffold for Android, iOS, Linux, macOS, and Windows.
- Pure Dart E2EE model and storage contracts.
- Federated hardware-key plugin scaffold for all target platforms.
- Architecture and threat-model documents.

## M1 — local encrypted notes

- Freeze canonical operation and encrypted-object protocol version 1.
- Publish deterministic cross-language test vectors.
- Implement authenticated operation encryption in `e2ee_core`.
- Implement immutable filesystem storage and the minimal editor UI.

## M2 — hardware-backed vault key

- Import Keybridge formats through specification.
- Implement macOS Secure Enclave and Linux TPM adapters.
- Store one wrapped vault-key envelope per authorized device.
- Demonstrate one shared encrypted vault on macOS and Linux.

## M3 — mobile and Windows

- Add iOS Secure Enclave, Android Keystore/StrongBox, and Windows TPM adapters.
- Add authenticated QR pairing and device revocation.
- Run one conformance suite on all five platforms.

## M4 — provider independence

- Add S3-compatible/R2 and WebDAV adapters.
- Add ciphertext-only replication, health reporting, and repair.
- Specify snapshots, garbage collection, rollback detection, and recovery.
