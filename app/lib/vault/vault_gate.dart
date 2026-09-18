import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'opened_vault.dart';
import 'vault_builder.dart';
import 'vault_opener/vault_opener.dart';

class VaultGate extends StatefulWidget {
  const VaultGate({
    required this.vaultOpener,
    required this.builder,
    super.key,
  });

  final VaultOpener vaultOpener;
  final VaultBuilder builder;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> {
  Future<OpenedVault>? _vault;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  void _open() => setState(() {
    _vault = widget.vaultOpener(_requestPolicy);
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
  Widget build(BuildContext context) => FutureBuilder<OpenedVault>(
    future: _vault,
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
      return widget.builder(context, snapshot.data!);
    },
  );
}
