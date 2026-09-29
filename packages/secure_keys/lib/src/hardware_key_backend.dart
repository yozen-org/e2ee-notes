import 'dart:typed_data';

import 'key_capabilities.dart';
import 'recipient_key.dart';

/// The native operations a hardware key store must provide.
///
/// The envelope crypto (ECDH key agreement, HKDF, AES-GCM) lives in Dart; the
/// backend only generates a P-256 recipient key and computes an ECDH shared
/// secret with its own private key.
abstract interface class HardwareKeyBackend {
  Future<KeyCapabilities> capabilities();

  Future<RecipientKey> createRecipientKey({required bool requireUserPresence});

  Future<RecipientKey> openRecipientKey(Uint8List keyHandle);

  Future<Uint8List> sharedSecret({
    required Uint8List keyHandle,
    required Uint8List peerPublicKey,
  });
}
