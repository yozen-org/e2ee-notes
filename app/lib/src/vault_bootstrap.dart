import 'dart:io';

import 'package:hardware_keys/hardware_keys.dart';
import 'package:notes_repository/notes_repository.dart';

import 'local_vault.dart';
import 'vault_key_provider.dart';

// OSごとのProviderを選んで注入する。端末の機能判定はProviderが担当する。
Future<EncryptedNotesRepository> openLocalVault() {
  final VaultKeyProvider provider = switch (Platform.operatingSystem) {
    'macos' || 'ios' => AppleVaultKeyProvider(HardwareKeys()),
    _ => const SoftwareVaultKeyProvider(),
  };
  return LocalVault(keyProvider: provider).open();
}
