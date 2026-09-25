import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'app.dart';
import 'vault/vault_opener/filesystem_vault_opener.dart';

void main() {
  runApp(
    App(vaultOpener: FilesystemVaultOpener(secureKey: PlatformSecureKey())),
  );
}
