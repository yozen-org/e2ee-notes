import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'l10n/app_localizations.dart';
import 'notes/logic/notes_service.dart';
import 'notes/ui/notes_home_page.dart';
import 'vault/key_policy/key_policy_dialog.dart';
import 'vault/vault_controller/vault_controller.dart';
import 'vault/vault_controller/vault_state.dart';
import 'vault/vault_opener/vault_opener.dart';

sealed class _HomeState {
  const _HomeState();
}

final class _HomeLoading extends _HomeState {
  const _HomeLoading();
}

final class _HomeFailed extends _HomeState {
  const _HomeFailed(this.error);

  final Object error;
}

final class _HomeReady extends _HomeState {
  const _HomeReady(this.service);

  final NotesService service;
}

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
  _HomeState _state = const _HomeLoading();

  @override
  void initState() {
    super.initState();
    _vaultController = VaultController(vaultOpener: widget.vaultOpener)
      ..addListener(_onVaultChanged);
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

  void _onVaultChanged() {
    _transition(_vaultController.value);
  }

  Future<void> _transition(VaultState event) async {
    try {
      final next = switch (event) {
        VaultNotOpened() || VaultOpening() => const _HomeLoading(),
        VaultOpenFailed(:final error) => _HomeFailed(error),
        VaultOpened(:final vault) =>
          _HomeReady(await createNotesService(vault)),
      };
      if (mounted) setState(() => _state = next);
    } catch (error) {
      if (mounted) setState(() => _state = _HomeFailed(error));
    }
  }

  @override
  void dispose() {
    _vaultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_state) {
        _HomeLoading() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        _HomeFailed(:final error) =>
          _HomeFailedView(error: error, onRetry: _openVault),
        _HomeReady(:final service) => NotesHomePage(service: service),
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
