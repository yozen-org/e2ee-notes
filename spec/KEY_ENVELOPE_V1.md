# Vault-key envelope protocol version 1

This format wraps the 32-byte vault key `K` for one device recipient key. The
recipient private key is non-exportable hardware key material; its persisted
handle is device-local and must never be copied as a recovery credential.

## Recipient public document

- Algorithm: NIST P-256 ECDH
- `publicKey`: base64 of the 65-byte uncompressed ANSI X9.63 representation
- `keyID`: lowercase hexadecimal SHA-256 digest of those 65 bytes
- `suite`: `P256-HKDF-SHA256-AES256GCM`

The public document contains `version`, `suite`, `keyID`, and `publicKey`.
Pairing must authenticate this document before another device wraps `K` for it.

## Envelope

The sender creates a fresh ephemeral P-256 key and performs ECDH with the
recipient public key. HKDF-SHA256 derives a 32-byte wrapping key using:

- input key material: the ECDH shared secret
- salt: UTF-8 recipient `keyID`
- info: UTF-8 `yozen.e2ee-notes.key-wrap.v1`

AES-256-GCM encrypts `K` with a fresh 12-byte nonce and authenticates the UTF-8
string `<suite>:<recipientKeyID>`. CryptoKit's combined representation is
stored in `sealedKey`: base64 of nonce, ciphertext, then the 16-byte tag.

The envelope contains `version`, `suite`, `recipientKeyID`,
`ephemeralPublicKey`, and `sealedKey`. Every field is authenticated either by
key derivation, AAD, or cryptographic validation during unwrap.

This protocol is derived from `lab-keybridge`, with a product-specific HKDF
domain. It is intentionally not wire-compatible with the lab namespace.
