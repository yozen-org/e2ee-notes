import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:hardware_keys/hardware_keys.dart';
import 'package:notes_repository/notes_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storage_filesystem/storage_filesystem.dart';

final class LocalVault {
  static Future<EncryptedNotesRepository> open() async {
    final support = await getApplicationSupportDirectory();
    return openAt(
      Directory('${support.path}${Platform.pathSeparator}e2ee-notes'),
    );
  }

  static Future<EncryptedNotesRepository> openAt(
    Directory root, {
    HardwareKeys? hardwareKeys,
    bool enableHardwareForTesting = false,
  }) async {
    await root.create(recursive: true);
    final vaultKey = await _openVaultKey(
      root,
      hardwareKeys ?? HardwareKeys(),
      enableHardwareForTesting: enableHardwareForTesting,
    );
    final deviceIdBytes = await _readOrCreateBytes(
      File('${root.path}${Platform.pathSeparator}device-id.bin'),
      32,
    );
    final deviceId = deviceIdBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return EncryptedNotesRepository(
      store: FilesystemBlobStore(
        Directory('${root.path}${Platform.pathSeparator}storage'),
      ),
      vaultKey: vaultKey,
      deviceId: deviceId,
    );
  }

  static Future<Uint8List> _openVaultKey(
    Directory root,
    HardwareKeys hardwareKeys, {
    required bool enableHardwareForTesting,
  }) async {
    final softwareKey = File(
      '${root.path}${Platform.pathSeparator}vault-key.bin',
    );
    final handleFile = File(
      '${root.path}${Platform.pathSeparator}recipient-key.handle',
    );
    final envelopeFile = File(
      '${root.path}${Platform.pathSeparator}vault-key.envelope.json',
    );
    final publicFile = File(
      '${root.path}${Platform.pathSeparator}recipient-public.json',
    );

    if (!Platform.isMacOS && !Platform.isIOS && !enableHardwareForTesting) {
      return _readOrCreateBytes(softwareKey, 32);
    }
    final capabilities = await hardwareKeys.capabilities();
    if (!capabilities.available || !capabilities.hardwareBacked) {
      return _readOrCreateBytes(softwareKey, 32);
    }

    final hasHandle = await handleFile.exists();
    final hasEnvelope = await envelopeFile.exists();
    if (hasHandle != hasEnvelope) {
      throw const FormatException('incomplete hardware vault-key state');
    }

    if (hasHandle) {
      final vaultKey = await hardwareKeys.unwrapVaultKey(
        keyHandle: await handleFile.readAsBytes(),
        envelope: VaultKeyEnvelope.fromMap(
          _decodeMap(await envelopeFile.readAsString()),
        ),
      );
      if (await softwareKey.exists()) {
        final legacy = await softwareKey.readAsBytes();
        if (!_sameBytes(vaultKey, legacy)) {
          throw const FormatException(
            'hardware and software vault keys differ',
          );
        }
        await softwareKey.delete();
      }
      return vaultKey;
    }

    final vaultKey = await _readOrCreateBytes(softwareKey, 32);
    final recipient = await hardwareKeys.createRecipientKey();
    final envelope = await hardwareKeys.wrapVaultKey(
      vaultKey: vaultKey,
      recipient: recipient.publicKey,
    );
    final verified = await hardwareKeys.unwrapVaultKey(
      keyHandle: recipient.handle,
      envelope: envelope,
    );
    if (!_sameBytes(vaultKey, verified)) {
      throw const FormatException('hardware vault-key verification failed');
    }

    await handleFile.writeAsBytes(recipient.handle, flush: true);
    await envelopeFile.writeAsString(jsonEncode(envelope.toMap()), flush: true);
    await publicFile.writeAsString(
      jsonEncode(recipient.publicKey.toMap()),
      flush: true,
    );
    await softwareKey.delete();
    return vaultKey;
  }

  static Map<Object?, Object?> _decodeMap(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?>) {
      throw const FormatException('expected a JSON object');
    }
    return value;
  }

  static Future<Uint8List> _readOrCreateBytes(File file, int length) async {
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.length != length) {
        throw const FormatException('invalid local vault material');
      }
      return bytes;
    }
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
    await file.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
