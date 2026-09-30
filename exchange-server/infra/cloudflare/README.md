# Cloudflare

`e2ee-notes` の交換サーバー（ブラインドリレー）の Cloudflare リソース
（Worker、KV namespace、カスタムドメイン）を OpenTofu で管理する。

単一 Worker が `POST /v1/transfers` と `GET /v1/transfers/{token}` を配信し、
`e2eenotes.yozen.org` で公開する。state は R2 bucket `yozen-tfstate` の
`e2ee-notes-exchange/terraform.tfstate` に保存する。

## Credential

credential は `exchange-server/.env`（Git 管理対象外）に置く。
`.env.example` をコピーして値を設定する。`with-env` が `.env` を読み込み、
Terraform 用の `TF_VAR_*` と R2 の `AWS_ENDPOINT_URL_S3` を組み立てて
子プロセスに渡す。

```sh
cp ../.env.example .env
chmod 600 ../.env
```

`.env` の項目:

- `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_ZONE_ID`
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`（R2 tfstate 用）

```sh
./with-env tofu init -reconfigure
./with-env tofu plan
./with-env tofu apply
```

## DNS

Worker のカスタムドメイン `e2eenotes.yozen.org` は
`cloudflare_workers_custom_domain` で管理し、DNS record は Cloudflare が
自動で作成する。`yozen.org` の zone 自体は中央の `yozen` リポジトリで
管理しているため、DNS の切り離しで競合する場合は相談する。

## デプロイ手順（初回）

1. `tofu apply` 後、KV namespace ID を確認する。

   ```sh
   ./with-env tofu output -raw kv_namespace_id
   ```

2. この ID を `wrangler.jsonc` の `kv_namespaces[0].id` に設定する。
3. デプロイを実行する。

   ```sh
   cd ../.. # exchange-server ルート
   infra/cloudflare/with-env npm run deploy
   ```

4. `https://e2eenotes.yozen.org/v1/transfers` に `POST` して疎通確認する。
