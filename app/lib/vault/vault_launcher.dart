import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import '../notes/notes_home_page.dart';
import '../notes/encrypted_notes_repository.dart';
import 'local_vault.dart';
import 'vault_key_service.dart';

class VaultLauncher extends StatefulWidget {
  const VaultLauncher({this.openVault, super.key});
  final Future<EncryptedNotesRepository> Function(RequestKeyPolicy)? openVault;
  @override
  State<VaultLauncher> createState() => _VaultLauncherState();
}

class _VaultLauncherState extends State<VaultLauncher> {
  Future<EncryptedNotesRepository>? _repository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  void _open() => setState(() {
    _repository =
        widget.openVault?.call(_requestPolicy) ??
        LocalVault(
          secureKey: PlatformSecureKey(),
          requestPolicy: _requestPolicy,
        ).open();
  });

  Future<KeyPolicy> _requestPolicy(KeyCapabilities capabilities) async {
    if (!mounted) throw StateError('Vault opening cancelled');
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Save the vault key on this device?'),
        content: Text(
          capabilities.hardwareBacked
              ? 'Use this device’s hardware to protect the key that unlocks your notes.'
              : 'Hardware protection is unavailable. The key will be stored without hardware protection on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true) throw StateError('Vault opening cancelled');
    return KeyPolicy(allowSoftware: !capabilities.hardwareBacked);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<EncryptedNotesRepository>(
    future: _repository,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not open vault: ${snapshot.error}'),
                TextButton(onPressed: _open, child: const Text('Retry')),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return NotesHomePage(repository: Future.value(snapshot.data!));
    },
  );
}
