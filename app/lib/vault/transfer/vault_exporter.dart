import 'dart:typed_data';

import 'package:secure_keys/secure_keys.dart';

import '../../storage/blob_store.dart';
import '../opened_vault.dart';
import 'vault_transfer.dart';

/// Packages an opened vault so another device can restore it.
final class VaultExporter {
  const VaultExporter({required this.secureKey});

  final SecureKey secureKey;

  Future<VaultTransfer> export({
    required OpenedVault vault,
    required RecipientPublicKey recipient,
  }) async {
    final envelope = await secureKey.envelope(vault.vaultKey, recipient);
    return VaultTransfer(
      vaultKeyEnvelope: envelope,
      objects: await _readObjects(vault.store),
    );
  }

  Future<Map<String, Uint8List>> _readObjects(BlobStore store) async {
    final objects = <String, Uint8List>{};
    for (final key in await store.list('')) {
      objects[key] = await store.get(key);
    }
    return objects;
  }
}
