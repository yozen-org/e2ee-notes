import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';
import 'package:secure_keys/src/secure_enclave/secure_enclave_secure_key.dart';
import 'package:secure_keys/src/tpm/tpm_secure_key.dart';
import 'package:secure_keys/src/software_secure_key.dart';
import 'package:e2ee_notes/notes/encrypted_notes_repository.dart';
import 'package:e2ee_notes/notes/notes_repository_factory/encrypted_notes_repository_factory.dart';
import 'package:e2ee_notes/vault/filesystem_vault_opener.dart';
import 'package:e2ee_notes/vault/file_vault_key_storage.dart';
import 'package:e2ee_notes/vault/opened_vault.dart';

import '../../../packages/secure_keys/test/support/fake_tpm_keys.dart';
import '../../../packages/secure_keys/test/support/fake_secure_enclave_keys.dart';

void main() {
  late Directory root;
  late FakeTpmKeys tpm;
  late SecureKey keys;
  const repositoryFactory = EncryptedNotesRepositoryFactory();
  int permissions = 0;
  Future<KeyPolicy> permit(KeyCapabilities caps) async {
    permissions++;
    return KeyPolicy(allowSoftware: !caps.hardwareBacked);
  }

  File file(String name) => File('${root.path}/$name');
  FilesystemVaultOpener vaultOpener() =>
      FilesystemVaultOpener(secureKey: keys, requestPolicy: permit);
  Future<OpenedVault> openVault() => vaultOpener().openAt(root);
  Future<EncryptedNotesRepository> openNotes() async =>
      repositoryFactory.create(await openVault());
  Future<Uint8List> openKey() async {
    await openVault();
    return keys.open((await FileVaultKeyStorage(root).read())!);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vault-lifecycle-');
    tpm = FakeTpmKeys();
    keys = PlatformSecureKey.withHardware(TpmSecureKey(tpm));
    permissions = 0;
  });
  tearDown(() => root.delete(recursive: true));

  test('new vault requires consent once and notes survive restart', () async {
    final notes = await openNotes();
    await notes.save(title: 'Private', body: 'Keep this note');
    final device = await file('device-id.bin').readAsBytes();
    final record = await file('vault-key.json').readAsBytes();
    final reopened = await openNotes();
    expect((await reopened.loadNotes()).single.body, 'Keep this note');
    expect(await file('device-id.bin').readAsBytes(), device);
    expect(await file('vault-key.json').readAsBytes(), record);
    expect(await file('vault-key.bin').exists(), isFalse);
    expect(permissions, 1);
    expect(tpm.keys, hasLength(1));
  });
  test('cancelled permission does not generate or persist a key', () async {
    final cancelled = FilesystemVaultOpener(
      secureKey: keys,
      requestPolicy: (_) async => throw StateError('cancelled'),
    );
    await expectLater(cancelled.openAt(root), throwsStateError);
    expect(tpm.keys, isEmpty);
    expect(await file('vault-key.json').exists(), isFalse);
  });
  test(
    'legacy software key migrates without changing existing notes',
    () async {
      keys = PlatformSecureKey.withHardware(SoftwareSecureKey());
      final notes = await openNotes();
      await notes.save(title: 'Before', body: 'Keep this note');
      final key = await openKey();
      await file('vault-key.bin').writeAsBytes(key);
      await file('vault-key.json').delete();
      keys = PlatformSecureKey.withHardware(TpmSecureKey(tpm));
      final restored = await openNotes();
      expect((await restored.loadNotes()).single.body, 'Keep this note');
      expect(await openKey(), key);
      expect(await file('vault-key.bin').exists(), isFalse);
    },
  );
  test(
    'existing legacy TPM state imports without generating another key',
    () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final blob = await tpm.protect(key);
      await file('vault-key.tpm').writeAsBytes(blob);
      expect(await openKey(), key);
      expect(permissions, 0);
      expect(tpm.keys, hasLength(1));
      expect(await openKey(), key);
    },
  );
  test(
    'legacy Apple state imports without public file or key generation',
    () async {
      final native = FakeSecureEnclaveKeys();
      keys = PlatformSecureKey.withHardware(SecureEnclaveSecureKey(native));
      final generated = await keys.generate(policy: const KeyPolicy());
      final data = generated.record.data;
      await file('recipient-key.handle')
          .writeAsBytes(base64Decode(data['handle'] as String));
      await file('vault-key.envelope.json')
          .writeAsString(jsonEncode(data['envelope']));
      expect(await openKey(), generated.vaultKey);
      expect(native.generatedKeys, 1);
      expect(permissions, 0);
    },
  );
  test(
    'hardware loss preserves stored record and leftover plaintext',
    () async {
      final key = await openKey();
      final saved = await file('vault-key.json').readAsBytes();
      await file('vault-key.bin').writeAsBytes(key);
      tpm.available = false;
      await expectLater(openKey(), throwsStateError);
      expect(await file('vault-key.json').readAsBytes(), saved);
      expect(await file('vault-key.bin').readAsBytes(), key);
      expect(tpm.keys, hasLength(1));
    },
  );
  for (final failure in ['protect', 'verify', 'persist']) {
    test('$failure failure retains the original legacy key', () async {
      final original = Uint8List(32);
      await file('vault-key.bin').writeAsBytes(original);
      if (failure == 'protect') {
        tpm.beforeProtect = () async => throw StateError('failed');
      }
      if (failure == 'verify') tpm.transformRestored = (key) => key..[0] ^= 1;
      if (failure == 'persist') {
        await Directory(file('vault-key.json').path).create();
      }
      await expectLater(openKey(), throwsA(anything));
      expect(await file('vault-key.bin').readAsBytes(), original);
    });
  }
  for (final name in [
    'recipient-key.handle',
    'vault-key.envelope.json',
    'vault-key.tpm',
  ]) {
    test('invalid legacy state stops creation: $name', () async {
      await file(name).writeAsBytes([1]);
      await expectLater(openKey(), throwsA(anything));
      expect(tpm.keys, isEmpty);
      expect(await file('vault-key.json').exists(), isFalse);
    });
  }
  for (final matching in [false, true]) {
    test(
      'leftover plaintext is removed only after equality check: $matching',
      () async {
        final original = await openKey();
        final leftover = Uint8List.fromList(original);
        if (!matching) leftover[0] ^= 1;
        await file('vault-key.bin').writeAsBytes(leftover);
        if (matching) {
          expect(await openKey(), original);
          expect(await file('vault-key.bin').exists(), isFalse);
        } else {
          await expectLater(openKey(), throwsFormatException);
          expect(await file('vault-key.bin').readAsBytes(), leftover);
        }
      },
    );
  }
  test('corrupt current record never triggers key creation', () async {
    await file('vault-key.json').writeAsString('bad json');
    await expectLater(openKey(), throwsFormatException);
    expect(tpm.keys, isEmpty);
    expect(permissions, 0);
  });
  test(
    'software fallback persists the same key until hardware is available',
    () async {
      tpm.available = false;
      final original = await openKey();
      expect(await openKey(), original);
      expect(permissions, 1);
      tpm.available = true;
      expect(await openKey(), original);
      expect(permissions, 2);
      expect(
        keys.isSoftware((await FileVaultKeyStorage(root).read())!),
        isFalse,
      );
    },
  );
  test('invalid plaintext length prevents protection', () async {
    await file('vault-key.bin').writeAsBytes([1, 2, 3]);
    await expectLater(openKey(), throwsFormatException);
    expect(tpm.keys, isEmpty);
  });
}
