import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hardware_keys/hardware_keys.dart';
import 'package:path/path.dart' as p;

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

    final softwareKey = File(p.join(root.path, 'vault-key.bin'));
    final handleFile = File(p.join(root.path, 'recipient-key.handle'));
    final envelopeFile = File(p.join(root.path, 'vault-key.envelope.json'));
    final publicFile = File(p.join(root.path, 'recipient-public.json'));

    final hasHandle = await handleFile.exists();
    final hasEnvelope = await envelopeFile.exists();
    if (hasHandle != hasEnvelope) {
      throw const FormatException('incomplete hardware vault-key state');
    }

    if (hasHandle) {
      final vaultKey = await hardwareKeys.unwrapVaultKey(
        keyHandle: await handleFile.readAsBytes(),
        envelope: VaultKeyEnvelope.fromMap(
          _decodeMap(await envelopeFile.readAsString()),
        ),
      );
      if (await softwareKey.exists()) {
        final legacy = await softwareKey.readAsBytes();
        if (!_sameBytes(vaultKey, legacy)) {
          throw const FormatException(
            'hardware and software vault keys differ',
          );
        }
        await softwareKey.delete();
      }
      return vaultKey;
    }

    final vaultKey = await const SoftwareVaultKeyProvider().openKey(root);
    final recipient = await hardwareKeys.createRecipientKey();
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

    await handleFile.writeAsBytes(recipient.handle, flush: true);
    await envelopeFile.writeAsString(jsonEncode(envelope.toMap()), flush: true);
    await publicFile.writeAsString(
      jsonEncode(recipient.publicKey.toMap()),
      flush: true,
    );
    await softwareKey.delete();
    return vaultKey;
  }

  static Map<Object?, Object?> _decodeMap(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?>) {
      throw const FormatException('expected a JSON object');
    }
    return value;
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
