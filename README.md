# Spec Ramo

[English](README.en.md)

Spec Ramo (スペックラモ) は、仕様を PR 単位の Phase に分け、実装者が理解してから Phase を 1 つずつ進める spec 駆動開発の Claude Code plugin です。

- 名前の由来: spec (仕様) + ramo (スペイン語・イタリア語で「枝」)。仕様から Phase ごとの PR へ枝分かれしていきます
- 状態: v0.3.0

## 何ができるか

- PRD、Design Doc、作業計画書、Phase 詳細設計を、決まった雛形と検査 script で作れます
- 作業計画書は 1 Phase = 1 PR に分かれます。各 PR の想定の変更行数が上限 (初期値 400 行) を超えないかを script が検査します
- 実装の前後で `/specramo:explain` が設計とコードを説明し、理解を確かめる質問を 1 つ返します
- `/specramo:review` は観点ごとに別のエージェント (設計書との比較 / 過去の指摘 / repo の規約 / 言語の開発指針) で並列に review します
- 各 Phase の状態 (未着手 / 実装中 / レビュー済み / PR 作成済み) は作業計画書の表に記録され、`/specramo:status` で一覧できます

## 導入

Claude Code の session で次の 2 つを実行します。

```text
/plugin marketplace add DaichiHoshina/spec-ramo
/plugin install specramo@specramo
```

session 内の `/plugin install` は、plugin の詳細画面を開きます。scope (user / project) を決めてからインストールしてください。shell からは `claude plugin install specramo@specramo` でもインストールできます。

インストールしたら、導入先の repo で `/specramo:init` を実行します。設定 file (`.specramo/config.yml`) と成果物の置き場所 (`.specramo/specs/`) を作ります。既にある file は変更しません。

### private repo から導入するとき

Claude Code は独自の token を使わず、手元の git の認証情報で clone します。この repo が private の間は、次のどちらかを済ませてから `/plugin marketplace add` を実行してください。

- SSH の鍵を GitHub に登録する。passphrase の入力なしで使える鍵にし、`github.com` を `known_hosts` に登録しておく
- `gh auth login` と `gh auth setup-git` で、git が GitHub CLI の認証を使うようにする

環境変数 `GITHUB_TOKEN` を設定するだけでは認証されません。

### plugin の更新

自分で追加した marketplace は、初期状態では自動更新されません。新しい版に更新するときは次の順に実行します。

1. `/plugin marketplace update specramo` で一覧を更新する
2. `/plugin` の Installed タブで Spec Ramo を開き、Update now を押す (shell からは `claude plugin update specramo@specramo`)
3. `/reload-plugins` で、実行中の session に反映する

自動更新にしたいときは、`/plugin` の Marketplaces タブで specramo を開き、Enable auto-update を押します。

## コマンド

PRD から PR までは、次の順に進めます。

| 順 | コマンド | すること |
|---|---|---|
| 1 | `/specramo:init` | 設定 file と成果物の置き場所を作る |
| 2 | `/specramo:prd` | 対話で要件を集めて PRD を作る |
| 3 | `/specramo:design` | 受け入れ条件の表で振る舞いを固定した Design Doc を作る |
| 4 | `/specramo:plan` | Design Doc を 1 Phase = 1 PR の作業計画書に分ける |
| 5 | `/specramo:phase-design` | Phase 1 つの実装方法を、既存 code を調べてから決める (判断の無い Phase では省く) |
| 6 | `/specramo:explain` | 実装前に Phase の設計を説明する |
| 7 | `/specramo:implement` | Phase を 1 つ実装し、完了条件を command で確かめる |
| 8 | `/specramo:review` | Phase の差分を 4 つの観点で並列に review する |
| 9 | `/specramo:explain` | 実装後に差分のコードを説明する。理解できたら利用者が PR を作る |
| - | `/specramo:status` | 機能ごとの Phase の進み具合と、この後に実行するコマンドを表示する |

5 から 9 を Phase ごとに繰り返します。PR は利用者が作ります。Spec Ramo は PR を作りません。

## 前提

手順と検査 script は、リレーショナル DB を使う Web API のバックエンド開発を想定しています。

- 言語別の開発指針 (`/specramo:review` の観点の 1 つ) は Go と TypeScript だけです。ほかの言語でも使えますが、その観点の review は行われません
- 設計書の検査は HTTP の status code と、MySQL のロック (`SELECT ... FOR UPDATE`、gap lock) を前提にしています。PostgreSQL では同じロックでも挙動が違うので、指摘を読み替えてください
- table を読む箇所の数え上げ (`scripts/table-readers.sh`) は SQL の文字列 (`FROM` / `JOIN`) だけを数えます。ORM の method で読む箇所は数えないので、ORM を使う repo では呼び出し元を別に調べてください
- CLI、バッチだけの変更、フロントエンドだけの変更では、設計書の検査の一部 (status code の数など) が当てはまりません

## 使わない場面

Spec Ramo は、PR が 2 本以上に分かれる大きさの開発を対象にしています。typo の修正や 1 file の小さな修正は、PRD から始めずに直接実装してください。

## 設定

`.specramo/config.yml` の項目です。

| key | 初期値 | 意味 |
|---|---|---|
| `specs_dir` | `.specramo/specs` | 成果物を置く dir。機能ごとに sub dir を作る |
| `max_lines` | `400` | 1 PR の想定の変更行数の上限 (テストを除く) |
| `test_paths` | なし | 変更行数から除くテスト file の path pattern |
| `branch_pattern` | なし | Phase の branch 名の形 (例: `phase/<PR>-<slug>`)。未記入なら名前があるかだけを検査する |
| `rules` | なし | review のエージェント C が読む規約 file。未記入なら `.claude/rules/` の file を読む |

環境変数 `SPECRAMO_REVIEW_DATA_DIR` で、review のエージェント B が読む指摘データの dir を指定できます。初期値は `~/.config/specramo/review-data/` です。指摘データはチームの過去の review から作る file で、社内情報を含むので repo には置きません。dir に file が無ければ B は起動しません。

雛形を repo 独自のものにしたいときは、`.specramo/templates/<prd|design|plan|phase-design>.md` に同じ名前の file を置きます。

## サンプル

[examples/overdue-todos](examples/overdue-todos/) に、PRD から Phase 詳細設計までの成果物がそろっています。題材は、小さな TODO API に「期限切れの TODO の一覧」を追加する機能です。

## 開発

```bash
bats tests/                          # script と skill の test
bash scripts/check-ai-tools-refs.sh  # 作者の手元にしか無い path が混ざっていないか
claude plugin validate .             # plugin の定義の検査
```

リリースするときは `.claude-plugin/plugin.json` の `version` を上げます。version が同じままだと、利用者が更新しても新しい commit が届きません。

## License

[MIT](LICENSE)
