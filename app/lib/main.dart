import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'app.dart';
import 'vault/local_vault.dart';

void main() {
  runApp(
    E2eeNotesApp(
      openVault: (requestPolicy) => LocalVault(
        secureKey: PlatformSecureKey(),
        requestPolicy: requestPolicy,
      ).open(),
    ),
  );
}
