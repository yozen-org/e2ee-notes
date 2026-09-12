import 'dart:io';

import 'package:secure_keys/secure_enclave.dart';
import 'package:secure_keys/tpm.dart';
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
      storage: SecureEnclaveVaultKeyStorage(root, SecureEnclaveKeys()),
      migrationSource: plaintext,
    ),
    'windows' || 'linux' => VaultKeyProvider(
      storage: TpmVaultKeyStorage(root, const MethodChannelTpmKeys()),
      migrationSource: plaintext,
    ),
    _ => VaultKeyProvider(storage: plaintext),
  };
}
