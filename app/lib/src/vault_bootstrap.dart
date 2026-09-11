import 'dart:io';

import 'package:hardware_keys/hardware_keys.dart';
import 'package:notes_repository/notes_repository.dart';

import 'local_vault.dart';
import 'vault_key_provider/apple_vault_key_provider.dart';
import 'vault_key_provider/software_vault_key_provider.dart';
import 'vault_key_provider/vault_key_provider.dart';

Future<EncryptedNotesRepository> openLocalVault() {
  final VaultKeyProvider provider = switch (Platform.operatingSystem) {
    'macos' || 'ios' => AppleVaultKeyProvider(HardwareKeys()),
    _ => const SoftwareVaultKeyProvider(),
  };
  return LocalVault(keyProvider: provider).open();
}
