# Operation protocol version 1

## Plaintext operation

An operation is UTF-8 JSON with fields emitted in this exact order:

1. `version`
2. `operationID`
3. `noteID`
4. `deviceID`
5. `sequence`
6. `timestampMicros`
7. `kind`
8. `baseOperationID`, when present
9. `title`, when present
10. `body`, when present

Version 1 uses compact JSON without insignificant whitespace. Identifiers are
32 random bytes encoded as 64 lowercase hexadecimal characters. Timestamps are
signed microseconds since the Unix epoch. `kind` is `create`, `update`, or
`delete`.

JSON object ordering is specified only to produce reproducible conformance
vectors. Readers must accept fields in any order and reject unsupported
versions.

## Encrypted object

- Algorithm: AES-256-GCM
- Key: the 32-byte vault key `K`
- Nonce: fresh random 12 bytes per object
- Authentication tag: 16 bytes
- Associated data: UTF-8 `yozen.e2ee-notes.operation.v1:<objectID>`
- `ciphertext`: base64 of ciphertext followed by the authentication tag

The storage key is `operations/<objectID>.json`. The operation ID, encrypted
object ID, and storage object ID must match. Moving ciphertext to another object
key therefore fails authentication or identity validation.

The JSON envelope fields are `version`, `suite`, `objectID`, `nonce`, and
`ciphertext`. Version 1's suite string is `AES-256-GCM`.

