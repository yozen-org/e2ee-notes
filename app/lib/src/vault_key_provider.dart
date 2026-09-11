import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hardware_keys/hardware_keys.dart';

import 'local_material.dart';

// 保管庫の鍵の取得方法を切り替える契約。呼び出し側が保存ルートを用意する。
abstract interface class VaultKeyProvider {
  Future<Uint8List> openKey(Directory root);
}

// ハードウェア保護が使えない環境向けの、暫定的な平文鍵ファイル保存。
final class SoftwareVaultKeyProvider implements VaultKeyProvider {
  const SoftwareVaultKeyProvider();

  @override
  Future<Uint8List> openKey(Directory root) => readOrCreateLocalBytes(
    File('${root.path}${Platform.pathSeparator}vault-key.bin'),
    32,
  );
}

// Apple端末の機能判定と、端末鍵による保護・復元・平文鍵からの移行を担当する。
// 非対応時のみソフトウェア鍵を使い、鍵操作の失敗はそのまま通知する。
final class AppleVaultKeyProvider implements VaultKeyProvider {
  AppleVaultKeyProvider(this.hardwareKeys);

  final HardwareKeys hardwareKeys;

  @override
  Future<Uint8List> openKey(Directory root) async {
    final capabilities = await hardwareKeys.capabilities();
    if (!capabilities.available || !capabilities.hardwareBacked) {
      return const SoftwareVaultKeyProvider().openKey(root);
    }

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

    // ハンドルとエンベロープの片方だけが残った状態では、新しい鍵で上書きせず失敗させる。
    final hasHandle = await handleFile.exists();
    final hasEnvelope = await envelopeFile.exists();
    if (hasHandle != hasEnvelope) {
      throw const FormatException('incomplete hardware vault-key state');
    }

    // 既存の端末鍵で保管庫の鍵を復元する。移行途中の平文鍵は一致を確認してから削除する。
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

    // 初回は鍵をラップし、復元できることを確認してから保護済みの情報を保存する。
    final vaultKey = await const SoftwareVaultKeyProvider().openKey(root);
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

    // 端末専用ハンドルと保護された鍵を保存した後、一時的な平文鍵ファイルを削除する。
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

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
