import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'home_state.dart';
import 'l10n/app_localizations.dart';
import 'notes/notes_home_page.dart';
import 'notes/notes_service.dart';
import 'vault/key_policy/key_policy_dialog.dart';
import 'vault/vault_controller/vault_controller.dart';
import 'vault/vault_controller/vault_state.dart';
import 'vault/vault_opener/vault_opener.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.vaultOpener,
    super.key,
  });

  final VaultOpener vaultOpener;

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

  Future<void> _handleVaultStateChanged() async {
    try {
      final home = await _mapToHomeState(_vaultController.state);
      if (mounted) setState(() => _state = home);
    } catch (error) {
      if (mounted) setState(() => _state = HomeFailed(error));
    }
  }

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
        HomeFailed(:final error) =>
          _HomeFailedView(error: error, onRetry: _openVault),
        HomeReady(:final service) => NotesHomePage(service: service),
      };
}

class _HomeFailedView extends StatelessWidget {
  const _HomeFailedView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.couldNotOpenVault('$error')),
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

Future<HomeState> _mapToHomeState(VaultState state) async => switch (state) {
      VaultNotOpened() || VaultOpening() => const HomeLoading(),
      VaultOpenFailed(:final error) => HomeFailed(error),
      VaultOpened(:final vault) => HomeReady(await createNotesService(vault)),
    };
