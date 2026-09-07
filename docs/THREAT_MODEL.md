# Threat model

Initially protected against:

- A storage provider reading note titles or bodies.
- Disclosure of stored objects without an authorized device key.
- Modification of an encrypted object without detection.
- Lock-in to one supported storage adapter.

Initially out of scope:

- A compromised unlocked client or malicious application build.
- Deletion, omission, or rollback of the complete object set.
- Object-size, timing, and access-pattern leakage.
- Loss of every authorized hardware key before recovery is implemented.
- Acceptance of an unauthenticated device public key during pairing.

Normal use initially has no application master passphrase. Local user presence,
device unlock, and hardware authorization are platform concerns. Passphrase
hardening and recovery envelopes are deferred extensions.
