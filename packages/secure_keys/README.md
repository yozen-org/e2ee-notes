# secure_keys

鍵の操作能力のインターフェースと、Secure Enclave・TPMへのネイティブ接続を提供するFlutterパッケージです。

## 公開API

- `package:secure_keys/secure_keys.dart`：鍵生成・署名・検証・暗号化・復号・鍵共有の契約。
- `package:secure_keys/secure_enclave.dart`：既存のSecure Enclave接続とデータ型。
- `package:secure_keys/tpm.dart`：既存のTPM接続。

操作能力のインターフェースは定義のみで、既存のネイティブ接続への適用は今後行います。
Dartの内部実装は`lib/src/secure_enclave/`と`lib/src/tpm/`に分け、
OS固有のネイティブ実装はFlutterのプラグインディレクトリに配置しています。

構成は[アーキテクチャ](../../docs/ARCHITECTURE.md)、TPMの導入方法は[TPM対応](../../docs/TPM.md)を参照してください。
