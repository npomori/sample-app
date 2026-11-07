# 参加アプリ

[astro-user-webauthn2](https://github.com/czbone/astro-user-webauthn2) の認証サーバーに連携する参加アプリです。ログイン、パスキー、ユーザー作成は行いません。仕様は [participant-app.md](https://github.com/czbone/astro-user-webauthn2/blob/main/planning/participant-app.md)、[multi-app-auth.md](https://github.com/czbone/astro-user-webauthn2/blob/main/planning/multi-app-auth.md)、[app-permissions](https://github.com/czbone/astro-user-webauthn2/blob/main/planning/app-permissions/README.md)、[ロールと認可](https://github.com/czbone/astro-user-webauthn2/blob/main/planning/auth-app-role-authorization-spec.md) です。

認証の骨格はパッケージ [astro-participant-auth](../astro-participant-auth) です。新しい参加アプリの作り方は [docs/building.md](docs/building.md) です。

未ログインの画面は認証サーバーの引き渡しへ送り、`/callback` でコードを消費してホスト専用の `__Host-session` を発行します。入場は実効許可が `allow` のときだけです。入場後の画面分けは共通ロール `User.role` を見ます。

## 画面

| パス          | 内容                                                     |
| ------------- | -------------------------------------------------------- |
| `/`           | メールアドレス、名前、共通ロール                         |
| `/grants`     | 共通 `admin` だけの利用許可の例外一覧                    |
| `/roles`      | 共通 `admin` または `manager` のアプリ内ロール           |
| `/callback`   | 引き渡しの戻り                                           |
| `/logged-out` | ログアウト完了。ヘッダはログイン。引き渡しは始めない     |

セッションがある画面のヘッダは「ログアウト」です。

未ログインの利用者には、上の画面を出しません。`/logged-out` だけはセッションなしで表示します。

## 動作確認

認証サーバーへ接続したあとの手順は [docs/verification.md](docs/verification.md) です。

## 権限

画面の権限とアクセス制御は [docs/access.md](docs/access.md) です。

## テスト

自動テストの分け方と確認内容は [docs/testing.md](docs/testing.md) です。

## セットアップ

認証サーバーを `http://auth.localhost:3000` で起動し、管理者が次を登録してからこのアプリを起動します。

- `App.id` は `app`
- `origin` は `http://app.localhost:4000`
- `redirectUris` に `http://app.localhost:4000/callback`
- 既定が `allow` でないアプリは、利用者ごとの `AppGrant` を `allow` にする。seed 管理者にも自動では付かない

PostgreSQL と Redis は認証サーバーと同じ場所へ、権限を絞った `app_participant` で接続します。手順は [docs/connections.md](docs/connections.md) です。このアプリはロールを作成せず、マイグレーションも実行しません。

```bash
pnpm install
cp .env.example .env
pnpm dev
```

`pnpm install` は、隣にある `astro-participant-auth` を `file:` で入れます。共有テーブルの Prisma Client は、そのパッケージの `prepare` が生成します。

ブラウザでは `http://app.localhost:4000` を開きます。`localhost` の別ポートではホスト専用 Cookie が混ざるため、ホスト名で分けます。

## コマンド

| コマンド     | 説明                                      |
| ------------ | ----------------------------------------- |
| `pnpm dev`   | `app.localhost:4000` で開発サーバーを起動 |
| `pnpm lint`  | ESLint                                    |
| `pnpm build` | 本番ビルド                                |

骨格のユニットテスト、統合テスト、`db:generate` は `astro-participant-auth` で実行します。接続先と準備は [docs/testing.md](docs/testing.md) です。共有テーブルの変更は認証サーバーだけが行います。`db:migrate` と `db:seed` はありません。

本番イメージのビルドコンテキストは、このリポジトリと `astro-participant-auth` の親ディレクトリです。公開するまでは `file:` 依存を解決するため、このリポジトリ単体をコンテキストにしません。

```bash
docker build -f astro-webauthn-app2/Dockerfile -t astro-webauthn-app2 .
```
