import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'home_state.dart';
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
  HomeState _state = const HomeLoading();

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
    _state = _mapToHomeState(_vaultController.state);
    setState(() {});
  }

  HomeState _mapToHomeState(VaultState state) => switch (state) {
        VaultNotOpened() || VaultOpening() => const HomeLoading(),
        VaultOpenFailed(:final error) => HomeFailed(error),
        VaultOpened(:final vault) =>
          HomeReady(widget.notesRepositoryFactory.create(vault)),
      };

  @override
  void dispose() {
    _vaultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_state) {
        HomeLoading() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        HomeFailed(:final error) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not open vault: $error'),
                TextButton(
                  onPressed: _openVault,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        HomeReady(:final repository) => NotesHomePage(repository: repository),
      };
}
