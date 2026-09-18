import 'dart:async';

import 'package:flutter/material.dart';

import 'opened_vault.dart';
import 'request_key_policy.dart';
import 'vault_builder.dart';
import 'vault_opener/vault_opener.dart';

class VaultGate extends StatefulWidget {
  const VaultGate({
    required this.vaultOpener,
    required this.requestPolicy,
    required this.builder,
    super.key,
  });

  final VaultOpener vaultOpener;
  final RequestKeyPolicy requestPolicy;
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

  void _open() {
    final result = Completer<OpenedVault>();
    setState(() {
      _vault = result.future;
    });
    // Let FutureBuilder subscribe before the opener can show UI or fail.
    WidgetsBinding.instance.addPostFrameCallback((_) => _completeOpen(result));
  }

  Future<void> _completeOpen(Completer<OpenedVault> result) async {
    if (!mounted) return;
    try {
      result.complete(await widget.vaultOpener(widget.requestPolicy));
    } on Object catch (error, stackTrace) {
      result.completeError(error, stackTrace);
    }
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
