# Protocol specifications

This directory is the language-independent source of truth for persisted
formats. A format is not implemented until it has a versioned schema,
deterministic test vectors, and passing Dart plus independent reference tests.

The first formats cover vault headers, recipient key envelopes, encrypted
operations, and immutable storage object names.
