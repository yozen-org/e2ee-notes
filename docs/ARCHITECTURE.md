# Architecture

```text
Flutter UI
    |
Application service
    +-- E2EE core
    +-- HardwareKey interface
    +-- Storage interface
             +-- filesystem
             +-- S3/R2, WebDAV, Drive (later)
```

The E2EE core owns versioned plaintext models, authenticated encryption,
operation ordering, conflicts, and snapshots. It does not import Flutter,
filesystem APIs, cloud SDKs, or platform key APIs.

Storage adapters receive opaque bytes and object keys. They never receive a
vault key or decrypted note. Hardware-key adapters create a non-exportable
recipient key, export its public document, and unwrap a vault-key envelope. They
never implement synchronization.

| Platform | Hardware-backed recipient key |
| --- | --- |
| macOS/iOS | Secure Enclave through Swift |
| Android | Android Keystore, preferring StrongBox |
| Windows | CNG Platform Crypto Provider / TPM |
| Linux | TPM 2.0 resource-manager device |

Hardware support is capability-based. A client must report whether its key is
hardware-backed rather than silently claiming equal assurance on every device.

```text
edit note
   -> canonical operation
   -> authenticated encryption with vault key K
   -> immutable encrypted object
   -> selected Storage adapter
```

Another authorized device unwraps the same `K`, lists immutable objects,
authenticates and decrypts them locally, and rebuilds note state.

During M1, the application bootstrap creates a random software vault key and
device ID in the platform application-support directory. Only the `storage/`
subdirectory is the provider root. The plaintext software key is a temporary
local bootstrap mechanism, not the intended security boundary; M2 replaces it
with a hardware-wrapped vault-key envelope.

The initial Dart filesystem adapter enforces immutability within normal
single-process application use. Cross-process atomic create and provider-level
conditional writes are explicit follow-up requirements before concurrent sync.
