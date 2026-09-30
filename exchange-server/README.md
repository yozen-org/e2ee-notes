# Exchange Server

ブラインドリレー（中継）サーバー。仕様は [`spec/EXCHANGE_SERVER_V1.md`](../spec/EXCHANGE_SERVER_V1.md)。

Cloudflare Workers + KV の参照実装です。暗号化済みペイロードを短命な URL で受け渡します。
サーバーは内容を復号できません。

## デプロイ

```sh
npm install
wrangler kv namespace create TRANSFERS
# wrangler.toml の id を上記の出力に差し替える
wrangler deploy
```

## ローカル実行

```sh
npm run dev
```

## 環境変数

- `MAX_PAYLOAD_BYTES`: ペイロード最大サイズ（既定 1 MiB）
- `TTL_SECONDS`: 転送の有効期間（既定 900 秒）

## セルフホスト

仕様は言語非依存です。このエンドポイントを満たす任意の実装（Go など）と相互運用できます。
クライアント側で「交換サーバー URL」を設定できます。
