import 'dart:convert';
import 'dart:typed_data';

import '../generated_key.dart';
import '../key_capabilities.dart';
import '../key_policy.dart';
import '../key_record.dart';
import '../secure_key.dart';
import '../vault_key_validation.dart';
import 'android_keystore_keys.dart';

final class AndroidKeystoreSecureKey extends SecureKey {
  AndroidKeystoreSecureKey(this.keys);
  final AndroidKeystoreKeys keys;
  Future<bool>? _available;

  @override
  Future<KeyCapabilities> capabilities() async => KeyCapabilities(
    hardwareBacked: await (_available ??= keys.isAvailable()),
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
      throw UnsupportedError('Android Keystore user presence is unsupported');
    }
    final protected = await keys.protect(vaultKey);
    final record = KeyRecord('android-keystore', {
      'alias': protected.alias,
      'iv': base64Encode(protected.iv),
      'ciphertext': base64Encode(protected.ciphertext),
    });
    requireMatchingVaultKeys(vaultKey, await open(record));
    return GeneratedKey(vaultKey, record);
  }

  @override
  Future<Uint8List> open(KeyRecord record) async {
    if (record.provider != 'android-keystore') {
      throw const FormatException('Unexpected key provider');
    }
    final key = await keys.unprotect(
      ProtectedVaultKey(
        alias: record.data['alias'] as String,
        iv: base64Decode(record.data['iv'] as String),
        ciphertext: base64Decode(record.data['ciphertext'] as String),
      ),
    );
    validateVaultKey(key);
    return key;
  }
}
