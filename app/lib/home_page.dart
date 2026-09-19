import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'notes/encrypted_notes_repository.dart';
import 'notes/notes_home_page.dart';
import 'notes/notes_repository_factory/notes_repository_factory.dart';
import 'vault/key_policy/key_policy_dialog.dart';
import 'vault/vault_controller/vault_controller.dart';
import 'vault/vault_controller/vault_state.dart';
import 'vault/vault_opener/vault_opener.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.vaultOpener,
    required this.notesRepositoryFactory,
    super.key,
  });

  final VaultOpener vaultOpener;
  final NotesRepositoryFactory notesRepositoryFactory;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final VaultController _vaultController;
  EncryptedNotesRepository? _notesRepository;

  @override
  void initState() {
    super.initState();
    _vaultController = VaultController(vaultOpener: widget.vaultOpener)
      ..addListener(_handleVaultStateChanged);
    _scheduleVaultOpening();
  }

  void _scheduleVaultOpening() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openVault();
    });
  }

  Future<void> _openVault() =>
      _vaultController.open(requestKeyPolicy: _requestKeyPolicy);

  Future<KeyPolicy> _requestKeyPolicy(KeyCapabilities capabilities) =>
      showKeyPolicyDialog(context, capabilities);

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
