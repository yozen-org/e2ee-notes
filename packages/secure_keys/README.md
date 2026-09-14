# secure_keys

Vault 鍵の生成・保護・復元を、ハードウェアを選ぶ処理も含めて提供します。
アプリは `package:secure_keys/secure_keys.dart` から `PlatformSecureKey` を作成し、
`SecureKey` の契約で利用します。Vault 鍵は32バイトの平文としてアプリに返し、
ノートの暗号化や保存先の管理はアプリが担当します。

## 契約

| 操作 | 結果 |
| --- | --- |
| `capabilities()` | ハードウェア保護・共有・ユーザー認証の対応状況 |
| `generate(policy: ...)` | 新しい Vault 鍵と `KeyRecord` |
| `protect(vaultKey, policy: ...)` | 既存 Vault 鍵と、それを保護した `KeyRecord` |
| `open(record)` | 同じ Vault 鍵。復元失敗時は別の鍵を作らない |
| `publicKey(record)` | 共有先として提示する公開鍵 |
| `envelope(vaultKey, recipient)` | 指定した共有先向けの Envelope |
| `accept(envelope, recipientRecord, policy: ...)` | 受信した Vault 鍵と、この端末での保存情報 |

`KeyRecord.encode()` のバイト列を保存し、読み込み時は `KeyRecord.decode()` で戻します。
Storage は provider や内部形式を解釈しません。レコードはこの端末での復元用であり、
他端末への共有には Envelope を使います。共有先公開鍵の信頼性確認と配送は呼び出し側の責務です。
受信には、先にこの端末で生成したレコードと、その公開鍵を共有先へ渡す手順が必要です。

`KeyPolicy` の既定値はハードウェア保護必須です。
ソフトウェア保存は `allowSoftware: true` を明示した場合に限ります。
これは暗号化された保存ではなく、平文鍵を含むレコードです。
`requireUserPresence` はネイティブ鍵の認証方針であり、アプリの保存確認ダイアログとは別です。
対応しない方針は例外にし、暗黙に緩めません。

Secure Enclave は共有に対応します。TPM は現在ローカルの protect/unprotect のみで、
`sharing` と `userPresence` は false、対応しない操作は `UnsupportedError` になります。
Android など未接続のプラットフォームはソフトウェア方式のみです。

## 互換性と低水準 API

`importLegacyKeyRecord` は以前のアプリの鍵ファイルをレコードへ変換する互換入口です。
ファイルの読み書きは行いません。
既存の `secure_enclave.dart`・`tpm.dart` と操作別インターフェースは互換性のため残しています。
通常のアプリでは、ハードウェア別 API を組み立てる必要はありません。

構成は[アーキテクチャ](../../docs/ARCHITECTURE.md)、TPMの導入方法は[TPM対応](../../docs/TPM.md)を参照してください。
