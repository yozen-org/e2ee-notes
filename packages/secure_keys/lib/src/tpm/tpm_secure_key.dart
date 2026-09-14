import 'dart:convert';
import 'dart:typed_data';

import '../generated_key.dart';
import '../key_capabilities.dart';
import '../key_policy.dart';
import '../key_record.dart';
import '../secure_key.dart';
import '../vault_key_validation.dart';
import 'tpm_keys.dart';

final class TpmSecureKey extends SecureKey {
  TpmSecureKey(this.keys);
  final TpmKeys keys;

  @override
  Future<KeyCapabilities> capabilities() async => KeyCapabilities(
    hardwareBacked: await keys.isAvailable(),
    sharing: false,
    userPresence: false,
  );

  @override
  Future<GeneratedKey> protect(
    Uint8List vaultKey, {
    required KeyPolicy policy,
  }) async {
    validateVaultKey(vaultKey);
    if (policy.requireUserPresence) {
      throw UnsupportedError('TPM user presence is unsupported');
    }
    final record = KeyRecord('tpm', {
      'protectedKey': base64Encode(await keys.protect(vaultKey)),
    });
    requireMatchingVaultKeys(vaultKey, await open(record));
    return GeneratedKey(vaultKey, record);
  }

  @override
  Future<Uint8List> open(KeyRecord record) async {
    if (record.provider != 'tpm') {
      throw const FormatException('Unexpected key provider');
    }
    final blob = base64Decode(record.data['protectedKey'] as String);
    if (blob.isEmpty || blob.length > 8192) {
      throw const FormatException('Invalid TPM key size');
    }
    final key = await keys.unprotect(blob);
    validateVaultKey(key);
    return key;
  }
}
