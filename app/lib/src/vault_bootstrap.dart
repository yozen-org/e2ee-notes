import 'dart:io';

import 'package:hardware_keys/hardware_keys.dart';
import 'package:hardware_keys/method_channel_tpm_keys.dart';
import 'package:notes_repository/notes_repository.dart';

import 'local_vault.dart';
import 'vault_key_provider.dart';
import 'vault_key_storage/plaintext_file_vault_key_storage.dart';
import 'vault_key_storage/secure_enclave_vault_key_storage.dart';
import 'vault_key_storage/tpm_vault_key_storage.dart';

Future<EncryptedNotesRepository> openLocalVault() =>
    LocalVault(keyProviderFactory: _createKeyProvider).open();

VaultKeyProvider _createKeyProvider(Directory root) {
  final plaintext = PlaintextFileVaultKeyStorage(root);
  return switch (Platform.operatingSystem) {
    'macos' || 'ios' => VaultKeyProvider(
      storage: SecureEnclaveVaultKeyStorage(root, HardwareKeys()),
      migrationSource: plaintext,
    ),
    'windows' || 'linux' => VaultKeyProvider(
      storage: TpmVaultKeyStorage(root, const MethodChannelTpmKeys()),
      migrationSource: plaintext,
    ),
    _ => VaultKeyProvider(storage: plaintext),
  };
}
