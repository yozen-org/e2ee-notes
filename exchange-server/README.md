# Exchange Server

ブラインドリレー（中継）サーバー。仕様は [`spec/EXCHANGE_SERVER_V1.md`](../spec/EXCHANGE_SERVER_V1.md)。

[Hono](https://hono.dev) による参照実装です。同じコードが Cloudflare Workers と
Node.js（VPS など）の両方で動きます。暗号化済みペイロードを短命な URL で受け渡します。
サーバーは内容を復号できません。

## 実行形態

ストレージだけを差し替えて、同じルーティング・ロジックを再利用します。

| 形態 | ストレージ | 起動方法 |
|---|---|---|
| Cloudflare Workers | KV | `wrangler deploy` |
| セルフホスト（Node.js） | インメモリ | `npm start` |

## Cloudflare Workers にデプロイ

```sh
npm install
wrangler kv namespace create TRANSFERS
# wrangler.toml の id を上記の出力に差し替える
wrangler deploy
```

## セルフホスト（Node.js / VPS）

```sh
npm install
npm start
# 既定で http://localhost:8787
```

Docker や任意の VPS 上で単一プロセスとして動かせます。

## 環境変数

- `MAX_PAYLOAD_BYTES`: ペイロード最大サイズ（既定 1 MiB）
- `TTL_SECONDS`: 転送の有効期間（既定 900 秒）
- `PORT`: セルフホスト時のポート（既定 8787）

## セルフホスト

仕様は言語非依存です。このエンドポイントを満たす任意の実装（Go など）と相互運用できます。
クライアント側で「交換サーバー URL」を設定できます。
