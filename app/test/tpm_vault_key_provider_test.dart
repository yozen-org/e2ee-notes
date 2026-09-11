import 'dart:io';
import 'dart:typed_data';

import 'package:e2ee_notes/src/local_vault.dart';
import 'package:e2ee_notes/src/vault_key_provider/software_vault_key_provider.dart';
import 'package:e2ee_notes/src/vault_key_provider/tpm_vault_key_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_keys/tpm_keys.dart';
import 'package:path/path.dart' as p;

final class FakeTpmKeys implements TpmKeys {
  bool available = true;
  int availabilityChecks = 0;
  final keys = <int, Uint8List>{};
  Future<void> Function()? beforeProtect;
  Uint8List Function(Uint8List)? transformRestored;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<Uint8List> protect(Uint8List vaultKey) async {
    await beforeProtect?.call();
    final id = keys.length + 1;
    keys[id] = Uint8List.fromList(vaultKey);
    return Uint8List.fromList([id]);
  }

  @override
  Future<Uint8List> unprotect(Uint8List protectedKey) async {
    if (!available) throw StateError('TPM unavailable');
    final key = protectedKey.length == 1 ? keys[protectedKey.single] : null;
    if (key == null) throw const FormatException('invalid protected key');
    final restored = Uint8List.fromList(key);
    return transformRestored?.call(restored) ?? restored;
  }
}

void main() {
  late Directory root;
  late File softwareKey;
  late File protectedKey;
  late FakeTpmKeys tpm;
  late TpmVaultKeyProvider provider;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tpm-vault-');
    softwareKey = File(p.join(root.path, 'vault-key.bin'));
    protectedKey = File(p.join(root.path, 'vault-key.tpm'));
    tpm = FakeTpmKeys();
    provider = TpmVaultKeyProvider(tpm);
  });

  tearDown(() => root.delete(recursive: true));

  test(
    'new key never touches plaintext disk and notes survive reopening',
    () async {
      tpm.beforeProtect = () async =>
          expect(await softwareKey.exists(), isFalse);
      final vault = LocalVault(keyProvider: provider);
      final repository = await vault.openAt(root);
      await repository.save(title: 'TPM', body: 'Keep this secret');
      final reopened = await vault.openAt(root);
      expect((await reopened.loadNotes()).single.body, 'Keep this secret');
      expect(await softwareKey.exists(), isFalse);
      expect(tpm.keys.length, 1);
      expect(
        await root.list().any(
          (entry) => p.basename(entry.path).startsWith('.tpm-key-'),
        ),
        isFalse,
      );
    },
  );

  test('migration preserves the key, device id and encrypted notes', () async {
    const software = LocalVault(keyProvider: SoftwareVaultKeyProvider());
    final original = await software.openAt(root);
    await original.save(title: 'Before', body: 'Existing note');
    final key = await softwareKey.readAsBytes();
    final device = File(p.join(root.path, 'device-id.bin'));
    final deviceId = await device.readAsBytes();
    tpm.beforeProtect = () async =>
        expect(await softwareKey.readAsBytes(), key);
    final migrated = await LocalVault(keyProvider: provider).openAt(root);
    expect((await migrated.loadNotes()).single.body, 'Existing note');
    expect(await device.readAsBytes(), deviceId);
    expect(await provider.openKey(root), key);
    expect(await softwareKey.exists(), isFalse);
  });

  test(
    'missing TPM uses software storage before a protected key exists',
    () async {
      tpm.available = false;
      final key = await provider.openKey(root);
      expect(await softwareKey.readAsBytes(), key);
      expect(await provider.openKey(root), key);
      expect(await protectedKey.exists(), isFalse);
    },
  );

  test('TPM loss never falls back or replaces the protected key', () async {
    final key = await provider.openKey(root);
    final blob = await protectedKey.readAsBytes();
    await softwareKey.writeAsBytes(key);
    tpm.available = false;
    tpm.availabilityChecks = 0;
    await expectLater(provider.openKey(root), throwsStateError);
    expect(tpm.availabilityChecks, 0);
    expect(await protectedKey.readAsBytes(), blob);
    expect(await softwareKey.readAsBytes(), key);
    expect(tpm.keys.length, 1);
  });

  for (final invalid in [
    Uint8List(0),
    Uint8List.fromList([255]),
    Uint8List(8193),
  ]) {
    test(
      'invalid protected file cannot trigger key generation: ${invalid.length}',
      () async {
        await protectedKey.writeAsBytes(invalid);
        await expectLater(provider.openKey(root), throwsFormatException);
        expect(tpm.keys, isEmpty);
        expect(await softwareKey.exists(), isFalse);
        expect(await protectedKey.readAsBytes(), invalid);
      },
    );
  }

  for (final failure in ['protect', 'verify', 'persist']) {
    test('$failure failure preserves the original software key', () async {
      final key = await const SoftwareVaultKeyProvider().openKey(root);
      switch (failure) {
        case 'protect':
          tpm.beforeProtect = () async => throw StateError('TPM failed');
        case 'verify':
          tpm.transformRestored = (value) => value..[0] ^= 1;
        case 'persist':
          await Directory(protectedKey.path).create();
      }
      final expectedFailure = switch (failure) {
        'protect' => throwsStateError,
        'verify' => throwsFormatException,
        _ => throwsA(isA<FileSystemException>()),
      };
      await expectLater(provider.openKey(root), expectedFailure);
      expect(await softwareKey.readAsBytes(), key);
      expect(await protectedKey.exists(), isFalse);
      expect(
        await root.list().any(
          (entry) => p.basename(entry.path).startsWith('.tpm-key-'),
        ),
        isFalse,
      );
    });
  }

  test(
    'failed creation verification leaves no plaintext or protected key',
    () async {
      tpm.transformRestored = (_) => Uint8List(31);
      await expectLater(provider.openKey(root), throwsFormatException);
      expect(await softwareKey.exists(), isFalse);
      expect(await protectedKey.exists(), isFalse);
    },
  );

  test('invalid software key fails without migration', () async {
    await softwareKey.writeAsBytes([1, 2, 3]);
    await expectLater(provider.openKey(root), throwsFormatException);
    expect(await softwareKey.readAsBytes(), [1, 2, 3]);
    expect(tpm.keys, isEmpty);
  });

  test('restored keys must be 32 bytes', () async {
    await provider.openKey(root);
    tpm.transformRestored = (_) => Uint8List(31);
    await expectLater(provider.openKey(root), throwsFormatException);
    expect(await softwareKey.exists(), isFalse);
  });

  for (final matching in [true, false]) {
    test(
      'leftover software key is removed only if matching: $matching',
      () async {
        final key = await provider.openKey(root);
        final leftover = Uint8List.fromList(key);
        if (!matching) leftover[0] ^= 1;
        await softwareKey.writeAsBytes(leftover);
        if (matching) {
          expect(await provider.openKey(root), key);
          expect(await softwareKey.exists(), isFalse);
        } else {
          await expectLater(provider.openKey(root), throwsFormatException);
          expect(await softwareKey.readAsBytes(), leftover);
        }
      },
    );
  }

  for (final filename in ['recipient-key.handle', 'vault-key.envelope.json']) {
    test(
      'Apple protected state prevents generating a different key: $filename',
      () async {
        await File(p.join(root.path, filename)).writeAsBytes([1]);
        await expectLater(provider.openKey(root), throwsFormatException);
        expect(tpm.availabilityChecks, 0);
        expect(await softwareKey.exists(), isFalse);
      },
    );
  }
}
