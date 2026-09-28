import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'l10n/app_localizations.dart';
import 'notes/logic/notes_service.dart';
import 'notes/ui/notes_screen.dart';
import 'vault/key_policy/key_policy_dialog.dart';
import 'vault/vault_opener/vault_opener.dart';

class Bootstrap extends StatefulWidget {
  const Bootstrap({required this.vaultOpener, super.key});

  final VaultOpener vaultOpener;

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    setState(() => _error = null);
    try {
      final vault = await widget.vaultOpener.open(
        requestKeyPolicy: _requestKeyPolicy,
      );
      final service = await createNotesService(vault);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => NotesScreen(service: service)),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<KeyPolicy> _requestKeyPolicy(KeyCapabilities capabilities) =>
      showKeyPolicyDialog(context, capabilities);

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return _BootFailedView(error: error, onRetry: _bootstrap);
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _BootFailedView extends StatelessWidget {
  const _BootFailedView({required this.error, required this.onRetry});

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
