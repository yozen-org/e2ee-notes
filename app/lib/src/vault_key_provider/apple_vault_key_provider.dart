import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hardware_keys/hardware_keys.dart';
import 'package:path/path.dart' as p;

import '../generate_random_bytes.dart';
import '../vault_key_files/recipient_key_handle_file.dart';
import '../vault_key_files/vault_key_envelope_file.dart';
import 'software_vault_key_provider.dart';
import 'vault_key_provider.dart';

final class AppleVaultKeyProvider implements VaultKeyProvider {
  AppleVaultKeyProvider(this.hardwareKeys);

  final HardwareKeys hardwareKeys;

  @override
  Future<Uint8List> openKey(Directory root) async {
    final capabilities = await hardwareKeys.capabilities();
    if (!capabilities.available || !capabilities.hardwareBacked) {
      return const SoftwareVaultKeyProvider().openKey(root);
    }
    return _openProtectedKey(root);
  }

  Future<Uint8List> _openProtectedKey(Directory root) async {
    if (await _hasProtectedKey(root)) {
      return _restoreKey(root);
    }
    final softwareKey = File(p.join(root.path, 'vault-key.bin'));
    if (await softwareKey.exists()) {
      return _migrateSoftwareKey(root, softwareKey);
    }
    return _createProtectedKey(root);
  }

  Future<bool> _hasProtectedKey(Directory root) async {
    final hasHandle = await RecipientKeyHandleFile(root).exists();
    final hasEnvelope = await VaultKeyEnvelopeFile(root).exists();
    if (hasHandle != hasEnvelope) {
      throw const FormatException('incomplete hardware vault-key state');
    }
    return hasHandle;
  }

  Future<Uint8List> _restoreKey(Directory root) async {
    final vaultKey = await hardwareKeys.unwrapVaultKey(
      keyHandle: await RecipientKeyHandleFile(root).read(),
      envelope: await VaultKeyEnvelopeFile(root).read(),
    );
    await _removeMatchingSoftwareKey(root, vaultKey);
    return vaultKey;
  }

  Future<void> _removeMatchingSoftwareKey(
    Directory root,
    Uint8List vaultKey,
  ) async {
    final softwareKey = File(p.join(root.path, 'vault-key.bin'));
    if (!await softwareKey.exists()) return;
    final legacy = await softwareKey.readAsBytes();
    if (!_sameBytes(vaultKey, legacy)) {
      throw const FormatException('hardware and software vault keys differ');
    }
    await softwareKey.delete();
  }

  Future<Uint8List> _createProtectedKey(Directory root) async {
    final vaultKey = generateRandomBytes(32);
    await _protectKey(root, vaultKey);
    return vaultKey;
  }

  Future<Uint8List> _migrateSoftwareKey(
    Directory root,
    File softwareKey,
  ) async {
    final vaultKey = await softwareKey.readAsBytes();
    if (vaultKey.length != 32) {
      throw const FormatException('invalid software vault-key length');
    }
    await _protectKey(root, vaultKey);
    await _removeMatchingSoftwareKey(root, vaultKey);
    return vaultKey;
  }

  Future<void> _protectKey(Directory root, Uint8List vaultKey) async {
    final recipient = await hardwareKeys.createRecipientKey();
    final envelope = await _wrapAndVerifyKey(vaultKey, recipient);
    await _persistProtectedKey(root, recipient, envelope);
  }

  Future<VaultKeyEnvelope> _wrapAndVerifyKey(
    Uint8List vaultKey,
    RecipientKey recipient,
  ) async {
    final envelope = await hardwareKeys.wrapVaultKey(
      vaultKey: vaultKey,
      recipient: recipient.publicKey,
    );
    final verified = await hardwareKeys.unwrapVaultKey(
      keyHandle: recipient.handle,
      envelope: envelope,
    );
    if (!_sameBytes(vaultKey, verified)) {
      throw const FormatException('hardware vault-key verification failed');
    }
    return envelope;
  }

  Future<void> _persistProtectedKey(
    Directory root,
    RecipientKey recipient,
    VaultKeyEnvelope envelope,
  ) async {
    await RecipientKeyHandleFile(root).write(recipient.handle);
    await VaultKeyEnvelopeFile(root).write(envelope);
    await File(p.join(root.path, 'recipient-public.json'))
        .writeAsString(jsonEncode(recipient.publicKey.toMap()), flush: true);
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
