import 'dart:convert';
import 'dart:typed_data';

import 'generated_key.dart';
import 'key_capabilities.dart';
import 'key_policy.dart';
import 'key_record.dart';
import 'secure_key.dart';
import 'vault_key_validation.dart';

final class SoftwareSecureKey extends SecureKey {
  @override
  Future<KeyCapabilities> capabilities() async => const KeyCapabilities(
    hardwareBacked: false,
    sharing: false,
    userPresence: false,
  );

  @override
  Future<GeneratedKey> protect(
    Uint8List vaultKey, {
    required KeyPolicy policy,
  }) async {
    if (!policy.allowSoftware || policy.requireUserPresence) {
      throw UnsupportedError('Requested key protection is unavailable');
    }
    validateVaultKey(vaultKey);
    return GeneratedKey(
      vaultKey,
      KeyRecord('software', {'key': base64Encode(vaultKey)}),
    );
  }

  @override
  Future<Uint8List> open(KeyRecord record) async {
    if (!isSoftware(record)) {
      throw const FormatException('Unexpected key provider');
    }
    final key = base64Decode(record.data['key'] as String);
    validateVaultKey(key);
    return key;
  }
}
