import 'package:flutter/material.dart';

import 'home_page.dart';
import 'l10n/app_localizations.dart';
import 'notes/notes_repository_factory/notes_repository_factory.dart';
import 'vault/vault_opener/vault_opener.dart';

class App extends StatelessWidget {
  const App({
    required this.vaultOpener,
    required this.notesRepositoryFactory,
    super.key,
  });

  final VaultOpener vaultOpener;
  final NotesRepositoryFactory notesRepositoryFactory;

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
      home: HomePage(
        vaultOpener: vaultOpener,
        notesRepositoryFactory: notesRepositoryFactory,
      ),
    );
  }
}
