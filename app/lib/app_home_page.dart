import 'package:flutter/material.dart';

import 'notes/encrypted_notes_repository.dart';
import 'notes/notes_home_page.dart';
import 'notes/notes_repository_factory/notes_repository_factory.dart';
import 'vault/key_policy_dialog.dart';
import 'vault/vault_controller/vault_controller.dart';
import 'vault/vault_controller/vault_state.dart';
import 'vault/vault_opener/vault_opener.dart';

class AppHomePage extends StatefulWidget {
  const AppHomePage({
    required this.vaultOpener,
    required this.notesRepositoryFactory,
    super.key,
  });

  final VaultOpener vaultOpener;
  final NotesRepositoryFactory notesRepositoryFactory;

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  late VaultController _vaultController;
  EncryptedNotesRepository? _notesRepository;

  @override
  void initState() {
    super.initState();
    _replaceVaultController();
    _scheduleVaultOpening();
  }

  @override
  void didUpdateWidget(covariant AppHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultOpener != widget.vaultOpener) {
      _vaultController.dispose();
      _replaceVaultController();
      _scheduleVaultOpening();
    } else if (oldWidget.notesRepositoryFactory !=
        widget.notesRepositoryFactory) {
      _createNotesRepositoryForOpenedVault();
    }
  }

  void _replaceVaultController() {
    _notesRepository = null;
    _vaultController = VaultController(vaultOpener: widget.vaultOpener)
      ..addListener(_handleVaultStateChanged);
  }

  void _scheduleVaultOpening() {
    final controller = _vaultController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(controller, _vaultController)) _openVault();
    });
  }

  Future<void> _openVault() => _vaultController.open(
    (capabilities) => showKeyPolicyDialog(context, capabilities),
  );

  void _handleVaultStateChanged() {
    _createNotesRepositoryForOpenedVault();
    setState(() {});
  }

  void _createNotesRepositoryForOpenedVault() {
    final state = _vaultController.state;
    _notesRepository = state is VaultOpened
        ? widget.notesRepositoryFactory.create(state.vault)
        : null;
  }

  @override
  void dispose() {
    _vaultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_vaultController.state) {
    VaultNotOpened() || VaultOpening() => const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
    VaultOpenFailed(:final error) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not open vault: $error'),
            TextButton(onPressed: _openVault, child: const Text('Retry')),
          ],
        ),
      ),
    ),
    VaultOpened() => NotesHomePage(repository: _notesRepository!),
  };
}
