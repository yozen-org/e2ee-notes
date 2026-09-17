import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'app.dart';
import 'vault/filesystem_vault_opener.dart';

void main() {
  runApp(
    E2eeNotesApp(
      openVault: (requestPolicy) => FilesystemVaultOpener(
        secureKey: PlatformSecureKey(),
        requestPolicy: requestPolicy,
      ).open(),
    ),
  );
}
