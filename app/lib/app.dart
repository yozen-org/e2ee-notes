import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'bootstrap.dart';
import 'l10n/app_localizations.dart';
import 'sync/sync_vault.dart';
import 'vault/vault_opener/vault_opener.dart';

class App extends StatelessWidget {
  const App({
    required this.vaultOpener,
    required this.secureKey,
    this.sync = syncVaultBestEffort,
    super.key,
  });

  final VaultOpener vaultOpener;
  final SecureKey secureKey;
  final SyncVault sync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff395b64)),
        useMaterial3: true,
      ),
      home: Bootstrap(
        vaultOpener: vaultOpener,
        secureKey: secureKey,
        sync: sync,
      ),
    );
  }
}
