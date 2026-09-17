import 'dart:typed_data';

import 'package:secure_keys/secure_keys.dart';

import 'vault_key_storage.dart';
import 'vault_key_validation.dart';

typedef RequestKeyPolicy = Future<KeyPolicy> Function(
  KeyCapabilities capabilities,
);

final class VaultKeyService {
  const VaultKeyService({
    required this.secureKey,
    required this.storage,
    required this.requestPolicy,
  });
  final SecureKey secureKey;
  final VaultKeyStorage storage;
  final RequestKeyPolicy requestPolicy;

  Future<Uint8List> loadOrCreateKey() async {
    final record = await storage.read();
    if (record == null) return _generate();
    final key = await secureKey.open(record);
    if (!secureKey.isSoftware(record)) return key;
    final capabilities = await secureKey.capabilities();
    if (!capabilities.hardwareBacked) return key;
    final policy = await requestPolicy(capabilities);
    return _save(await secureKey.protect(key, policy: policy));
  }

  Future<Uint8List> _generate() async {
    final policy = await requestPolicy(await secureKey.capabilities());
    return _save(await secureKey.generate(policy: policy));
  }

  Future<Uint8List> _save(GeneratedKey generated) async {
    requireMatchingVaultKeys(
      generated.vaultKey,
      await secureKey.open(generated.record),
    );
    await storage.save(generated.record);
    final restored = await secureKey.open((await storage.read())!);
    requireMatchingVaultKeys(generated.vaultKey, restored);
    return restored;
  }
}
