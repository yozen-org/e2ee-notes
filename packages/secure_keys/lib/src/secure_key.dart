import 'dart:math';
import 'dart:typed_data';

import 'generated_key.dart';
import 'key_capabilities.dart';
import 'key_policy.dart';
import 'key_record.dart';
import 'recipient_public_key.dart';
import 'vault_key_envelope.dart';

/// Hardware-independent vault-key lifecycle. No application filesystem access.
abstract class SecureKey {
  Future<KeyCapabilities> capabilities();

  Future<GeneratedKey> generate({required KeyPolicy policy}) {
    final random = Random.secure();
    final key = Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
    return protect(key, policy: policy);
  }

  Future<GeneratedKey> protect(Uint8List vaultKey, {required KeyPolicy policy});
  Future<Uint8List> open(KeyRecord record);

  /// True for a record explicitly stored without hardware protection.
  bool isSoftware(KeyRecord record) => record.provider == 'software';

  Future<RecipientPublicKey> publicKey(KeyRecord record) =>
      Future.error(UnsupportedError('Sharing is unavailable'));
  Future<VaultKeyEnvelope> envelope(
    Uint8List vaultKey,
    RecipientPublicKey recipient,
  ) => Future.error(UnsupportedError('Sharing is unavailable'));
  Future<GeneratedKey> accept(
    VaultKeyEnvelope envelope,
    KeyRecord recipient, {
    required KeyPolicy policy,
  }) => Future.error(UnsupportedError('Sharing is unavailable'));
}
