import 'dart:io';

import 'package:secure_keys/secure_enclave.dart';
import 'package:secure_keys/tpm.dart';
import 'package:notes_repository/notes_repository.dart';

import 'local_vault.dart';
import 'vault_key_selection/plaintext_vault_key_selector.dart';
import 'vault_key_selection/secure_enclave_vault_key_selector.dart';
import 'vault_key_selection/tpm_vault_key_selector.dart';
import 'vault_key_selection/vault_key_selector.dart';

Future<EncryptedNotesRepository> openLocalVault() =>
    LocalVault(keySelectorFactory: _createKeySelector).open();

VaultKeySelector _createKeySelector(Directory root) =>
    switch (Platform.operatingSystem) {
      'macos' ||
      'ios' => SecureEnclaveVaultKeySelector(root, SecureEnclaveKeys()),
      'windows' ||
      'linux' => TpmVaultKeySelector(root, const MethodChannelTpmKeys()),
      _ => PlaintextVaultKeySelector(root),
    };
