# Specramo PRD（plugin 版）

Sep 27, 2026 · @Daichi Hoshina

## 概要

Specramo（スペクラモ）は、仕様を PR 単位の Phase に分け、実装者が理解してから一段ずつ進める spec 駆動開発のツールキットである。v0.1 は Claude Code の plugin として配り、利用者は plugin を追加して `/specramo:init` を実行するだけで使い始められる。

- **名前の由来:** spec（仕様）＋ ramo（スペイン語・イタリア語で「枝」）。仕様から Phase ごとの PR へ枝分かれしていく
- **出発点:** ai-tools リポジトリの sdd 系コマンド（`/sdd-design` `/sdd-plan` `/sdd-phase-design` `/sdd-implement` `/sdd-review` `/explain`）を切り出す。`/prd` も取り込み、`/specramo:status` と `/specramo:init` は新しく作る
- **配り方:** v0.1〜v0.3 は Claude Code plugin。Claude Code 以外のエージェントに広げる段階（v0.4 以降）で、独自 CLI を作るかを決める

## 背景と課題

AI に大きな機能を一気に実装させると、コードは速くできるが、レビューと理解が追いつかない。既存の spec 駆動ツールは「仕様を書く」部分を解決したが、次の 3 つは解決していない。

| 課題 | 起きていること |
| --- | --- |
| PR が大きすぎる | レビュワーの負担が増え、PR リードタイムが伸びる |
| 仕様の判断が後回しになる | 実装時やレビュー時に仕様の抜けに気づき、人によって判断がぶれる |
| AI のコードを説明できない | 実装者の理解が足りず、レビュワーが先に問題に気づく |

## 目標と非目標

目的は、自分以外のメンバーも大型開発を小さな PR に分けて、自分で説明できる状態で出せるようにし、レビュー負担と PR リードタイムを下げることである。ai-tools の sdd 系コマンドを plugin にするのは、その手段である。

### 目標

- plugin を追加して `/specramo:init` を実行すれば、任意のリポジトリで使い始められる
- Design Doc → 作業計画書 → Phase ごとの実装とレビュー、の流れをスラッシュコマンドで再現できる
- 1 Phase = 1 PR（目安 400 行以下）を、検査スクリプトで守れる
- 実装の前後に `/specramo:explain` で実装者の理解を確かめる手順を標準にする
- リポジトリ固有の規約やチームの過去の指摘を、AI レビューの観点として差し込める

### 非目標

- **小さな修正の実装:** 文書を作る手間に見合わない。小さな修正は直接実装するか、Spec Kit の bug 用 extension などを使えば足りる
- **人のレビューの代替:** マージの判断は人が行う
- **v0.3 までの Claude Code 以外への対応:** 最初は Claude Code のみ。独自 CLI も v0.3 までは作らない
- **チームの過去の指摘データの同梱:** 社内情報を含むため、各自の手元に置く
- **IDE としての提供:** Kiro のように editor ごと乗り換えてもらう形は取らず、今使っているエージェントに外付けする

## 判断の根拠

v0.1 は Claude Code plugin で配る。v0.1 で確かめたいのは「自分以外の人が 1 機能を最後まで進められるか」であり、その確認に独自 CLI は要らないためである。

### 代替案との比較

| 案 | 良い点 | 弱い点 |
| --- | --- | --- |
| **Claude Code plugin（採用）** | command と agent の配布と更新を Claude Code に任せられる。CLI の実装とテストが不要 | 雛形や config を repo に置く処理は `/specramo:init` で別に作る。他エージェントへ広げるときは配り方を作り直す |
| 独自 CLI（Spec Kit と同じ形） | 配置も upgrade も自由に作れる。複数のエージェントに対応しやすい | CLI と検査 script の 2 つの実行環境を保守する。言語（Python か Go か）と更新の仕組みを v0.1 で決める必要がある |
| Spec Kit の extension / preset | 導入の仕組みと多エージェント対応を Spec Kit に任せられる | Spec Kit の工程（specify → plan → tasks）に合わせる必要があり、「単位 = PR」を通しにくい。Spec Kit の変更への追従も必要 |
| 作らない（ai-tools の file を手でコピーしてもらう） | 開発コストが 0 | sdd 系 5 command と `/explain` が直接参照する file が 32 件あり、手作業では再現できない |

独自 CLI は、Claude Code 以外のエージェントに対応する段階（v0.4 以降）で必要になったときに作る。

### 失敗の想定

半年後に失敗していたとしたら、原因は次の 3 つのどれかだと考える。

| 種類 | 失敗の想定 | 早く見つける兆候 |
| --- | --- | --- |
| 技術 | 検査 script が誤って FAIL を出し続け、利用者が結果を無視し始める | 同じ WARN / FAIL が毎回そのまま放置される |
| 運用 | ai-tools 側の改善が Specramo に反映されず、2 つの内容が離れていく | 両方の同じ command の中身が食い違う |
| 想定外の使い方 | 小さな修正にも全工程を使い、「重い」と評価されて使われなくなる | Phase が 1 つしかない作業計画書が増える |

### 前提が崩れる条件

- **「対象チームが Claude Code を使い続ける」が崩れた場合:** plugin の配り方は使えなくなる。command の本文と検査 script はそのまま使えるので、移行コストは配り方（CLI か変換層）を作る分に限られる
- **Claude Code の plugin 仕様が大きく変わった場合:** plugin の構成 file を書き直す。command 本文は影響を受けない

## 想定ユーザーと利用シーン

主なユーザーは、Claude Code で業務の大型開発を進めるバックエンドエンジニアである。

| ユーザー | 利用シーン | 求めるもの |
| --- | --- | --- |
| 実装者 | 複数サービスにまたがる機能を AI と作る | 設計を崩さずに小さな PR で進め、自分で説明できる状態で出す |
| レビュワー | 小さく分かれた PR を順に見る | PR ごとの目的と設計根拠が Design Doc で追える |
| EM・チームリード | チームの開発手法をそろえる | 誰が使っても同じ手順・同じ品質になる。repo の設定に plugin を書いておけば、メンバーに自動で案内される |

## Spec Kit / Kiro との比較と差別化

差別化の軸は「作業の単位を PR にそろえる」「実装者の理解を確かめる」「リポジトリの設計思想に沿った AI レビュー」の 3 つ。配り方は Spec Kit と同じ「今のエージェントに外付けする」型で、Kiro のように IDE ごと乗り換えてもらう形は取らない。

| 工程 | Spec Kit | Kiro | Specramo |
| --- | --- | --- | --- |
| 配り方 | CLI（`uv tool install specify-cli`）で repo に配置 | 専用の IDE（Code OSS ベース）、CLI、ブラウザ版 | Claude Code plugin |
| 導入 | `specify init` | IDE に内蔵 | plugin を追加して `/specramo:init` |
| 原則を決める | constitution | steering | リポジトリの規約・開発指針を読み込む |
| 要件を決める | specify（任意で clarify、checklist） | requirements | `/specramo:prd`、`/specramo:design` |
| 設計する | plan | design | `/specramo:design`、`/specramo:phase-design` |
| 作業に分ける | tasks | tasks | `/specramo:plan`（単位 = PR） |
| 実装する | implement | タスク実行 | `/specramo:implement`（1 Phase ずつ） |
| 差を確かめる | converge（任意で analyze） | なし | `/specramo:review`（観点別に並列） |
| 理解を確かめる | なし | なし | `/specramo:explain`（独自） |

Spec Kit は 2026-09-27 時点の README、Kiro は公式サイトと紹介記事による。Spec Kit には bug 修正用の extension（`bug-assess` / `bug-fix` / `bug-test`）もあり、小さな修正はそちらの対象である。

## 機能要件

v0.1 では、スラッシュコマンド 9 つ、検査スクリプト 2 つ、文書の雛形 4 つ、レビュー用エージェント 4 つを 1 つの plugin にまとめて提供する。独自 CLI（init / check / upgrade）は作らず、その役割は `/specramo:init` と Claude Code の plugin 更新の仕組みが引き受ける。

&#91;embedded content: Specramo の進め方 · 1 回の準備と Phase ごとの繰り返し\]

PRD から作業計画書までは 1 回だけ作る。その後は Phase ごとに、設計とコードを実装者が説明できることを確かめてから PR を出す。

### スラッシュコマンド

plugin のコマンドは `/specramo:<名前>` の形で呼ぶ（Claude Code の仕様）。実装は plugin の skill として作る。

| コマンド | 作るもの | 実装者が確かめること | 元になる ai-tools のコマンド |
| --- | --- | --- | --- |
| `/specramo:init` | `.specramo/` と `config.yml` | 設定の内容 | なし（新規） |
| `/specramo:prd` | PRD（要求） | 何を実現したいか | `/prd` |
| `/specramo:design` | Design Doc | 受け入れ条件と設計判断 | `/sdd-design` |
| `/specramo:plan` | 作業計画書（Phase = PR の一覧） | PR の分け方と順序 | `/sdd-plan` |
| `/specramo:phase-design` | Phase 詳細設計（選択肢がある Phase のみ） | トランザクション・排他制御・SQL の方針 | `/sdd-phase-design` |
| `/specramo:explain` | 設計・コードの説明と確認の質問 | 自分の言葉で説明できるか | `/explain` |
| `/specramo:implement` | Phase のコード | 完了条件のテストが通るか | `/sdd-implement` |
| `/specramo:review` | 指摘の一覧 | Critical / Warning が 0 件か | `/sdd-review` |
| `/specramo:status` | 現在地の表示 | どの Phase まで進んだか | なし（新規） |

各コマンドは次のコマンドを案内するが、自動では進まない。`/specramo:status` は `.specramo/specs/<機能名>/plan.md` の Phase ごとの状態欄を読んで表示する。

### 検査スクリプト

検査スクリプトは plugin に同梱し、コマンドから `${CLAUDE_PLUGIN_ROOT}` 経由で呼ぶ。元は ai-tools の `dd-gate.sh` と `spec-gate.sh` である。

- **Design Doc の検査:** 未確定の項目、曖昧な表現、実装の細部の混入を検出する。FAIL があれば次に進めない
- **作業計画書の検査:** PR ごとの想定変更行数、400 行超の理由、実装方法の混入を検出する

### 文書の雛形

PRD / Design Doc / 作業計画書 / Phase 詳細設計の 4 つ。plugin に同梱したものを標準とし、導入先の `.specramo/templates/` に同じ名前の file を置いたときだけ、そちらを優先する。

### AI レビュー（`/specramo:review`）

| エージェント | 確認すること | 実行条件 |
| --- | --- | --- |
| A｜設計書との比較 | Phase の範囲と受け入れ条件 | 常に |
| B｜過去の指摘 | チームが過去に受けた指摘の傾向 | 手元に指摘データがあるとき |
| C｜リポジトリ規約 | リポジトリ独自の規約 | `config.yml` に規約の場所があるとき |
| D｜言語・フレームワーク | 言語やフレームワークの開発指針 | 常に |

コードの修正は `--fix` を指定したときだけ行う。

## 構成と導入方法

配布用リポジトリが plugin と marketplace（plugin の配布元）を兼ねる。導入先に置くのは設定と成果物だけで、コマンド・スクリプト・雛形は plugin 側に置く。

### 導入手順（案）

```
/plugin marketplace add DaichiHoshina/specramo
/plugin install specramo@specramo
/specramo:init
```

- **チームで使う場合:** `claude plugin marketplace add DaichiHoshina/specramo --scope project` で `.claude/settings.json` に登録して commit する。メンバーはフォルダを信頼したときに plugin を案内される
- **公開前（private repo）の場合:** 利用者の手元の git が認証できる必要がある（SSH 鍵、または `gh auth login` と `gh auth setup-git`）
- **更新:** 公式以外の marketplace は自動更新が既定で無効なので、README で `/plugin marketplace update` の実行か自動更新の有効化を案内する。リリースごとに `plugin.json` の `version` を上げる

### 配布用リポジトリ（DaichiHoshina/specramo）

```
specramo/
├── .claude-plugin/
│   ├── plugin.json       # plugin の名前と version
│   └── marketplace.json  # この repo を配布元として登録する
├── skills/               # /specramo:* の 9 コマンド（1 コマンド = 1 skill）
├── agents/               # AI レビュー用エージェント A〜D
├── scripts/              # Design Doc・作業計画書の検査スクリプト
├── templates/            # PRD / Design Doc / 作業計画書 / Phase 詳細設計の雛形
├── docs/                 # 手法の説明（進め方、3 つの文書の書き分け、FAQ）
├── examples/             # 小さなサンプル機能での一連の成果物
├── tests/                # 検査スクリプトのテスト
├── README.md             # 概要、名前の由来、クイックスタート
└── LICENSE
```

### 導入先に作られるもの

```
your-repo/
└── .specramo/
    ├── config.yml        # ブランチ名の形、行数の上限、テストの path、規約の場所
    ├── templates/        # 任意。置いた雛形だけ plugin の標準より優先する
    └── specs/<機能名>/     # prd.md、design.md、plan.md、phases/
```

コマンドとスクリプトを導入先にコピーしないので、plugin を更新しても導入先の file は変わらない。利用者が変えた雛形を上書きする心配もない。

## 非機能要件

| 項目 | 要件 |
| --- | --- |
| 対応環境 | macOS と Linux。Claude Code、git、gh、bash |
| 対応エージェント | v0.3 までは Claude Code のみ。コマンド本文は Claude Code 固有の書き方を少なくし、他エージェントへ移しやすくしておく |
| 導入先への影響 | `/specramo:init` は既存の file を上書きしない。同じ名前の file があれば作らずにその旨を表示する |
| 秘密情報 | チームの過去の指摘データは repo に含めない。場所は環境変数か `~/.config/specramo/` で指定し、commit される `config.yml` には書かない |
| 検査スクリプト | bash と標準コマンドだけで動き、結果は PASS / FAIL / WARN の 1 行 1 判定で出す。CI からも単独で実行できる |
| ドキュメント | 日本語を正とし、英語版 README を用意する |
| ライセンス | 公開時は MIT（Spec Kit と同じ） |

## 成功指標と受け入れ条件

成功の判断は、「自分以外の人が導入して、大型開発を 1 本最後まで進められたか」で行う。数値の目標は、導入前の実績を測ってから決める。

### 成功指標（案）

| 指標 | 測り方 |
| --- | --- |
| PR の大きさ | Specramo で出した PR のうち、400 行以下の割合。行数は追加と削除の合計で、`config.yml` のテスト path に当たる file を除く |
| PR リードタイム | PR 作成からマージまでの時間。同じ repo の導入前の直近 20 本と比べる |
| レビューでの仕様の指摘 | 人のレビューで出た「仕様が決まっていない」指摘の件数 |
| 理解の確認 | `/specramo:explain` を実行してから出した PR の割合（`/specramo:status` で表示する） |
| 導入数 | 自分以外のメンバーが使ったリポジトリ数 |

### 受け入れ条件（v0.1）

- [ ] plugin を追加した空のリポジトリで `/specramo:init` を実行すると、`.specramo/config.yml` と `.specramo/specs/` が作られる
- [ ] `.specramo/` がすでにあるリポジトリで `/specramo:init` を実行しても、既存の file が変わらない
- [ ] examples/ のサンプル機能を、PRD から最後の Phase の PR 作成までコマンドだけで進められる（検証用の GitHub repo を使う）
- [ ] 検査スクリプトが、未確定の項目がある Design Doc と、400 行超の PR を理由なしで含む作業計画書を FAIL にする
- [ ] `/specramo:explain` を実行すると、Phase の目的・設計判断・変更箇所の説明と、理解を確かめる質問が表示される
- [ ] `config.yml` に規約の場所を書くと、`/specramo:review` のエージェント C がその規約で指摘を出す
- [ ] チームの指摘データが無い環境でも、`/specramo:review` がエージェント B を飛ばして最後まで動く
- [ ] ai-tools にしかない file（個人の memory、`~/.claude/` 配下の script など）を参照する箇所が 0 件である

## リリース計画

公開は v0.3 のゲート（社内情報の除去と商標の確認）を満たした後に行う。各段階の日付は未定。

&#91;embedded content: リリース計画 · 4 段階と 3 つのゲート\]

ひし形がゲートで、条件を満たすまで次の段階に進まない。v0.3 までは private repo のまま、メンバーに読み取り権限を渡して使ってもらう。

## リスクと未決事項

最大のリスクは、ai-tools の個人設定や社内情報に依存した部分が、切り出し後に動かなくなることである。

### リスク

| リスク | 対策 |
| --- | --- |
| コマンドが ai-tools の他の file に依存している。直接参照だけで 32 件（guidelines 8、references 12、rules 5、scripts 4、skills 3）あり、うち 3 コマンドは個人の memory と `~/.claude/plans/` を参照している | v0.1 で間接参照まで洗い出し、必要なものだけ plugin に同梱する。個人の memory への参照は削除する（受け入れ条件に含めた） |
| チームの指摘データや社内の規約が混ざる | 公開前に社内用語を検索して除去する（v0.3 のゲート） |
| 手順が多く、小さな変更には重い | 対象外を README に明記し、小さな修正は直接実装でよいとする |
| 公式以外の marketplace は自動更新が既定で無効なので、古い版のまま使われる | README で更新手順を案内する。`/specramo:status` で plugin の version も表示する |
| Spec Kit や Claude Code の仕様が変わり、比較や手順が古くなる | 比較表と導入手順に確認日を添える |

### 決定済み

- **配り方:** v0.1〜v0.3 は Claude Code plugin。独自 CLI は作らない
- **コマンド名:** `/specramo:<名前>`。plugin のコマンドはこの形で呼ぶ仕様なので、`/sdd-*` との比較は不要になった

### 未決事項

- [ ] ai-tools 側は Specramo を取り込む形にするか（ai-tools から sdd 系を消して plugin を使う）、両方に残すか
- [ ] v0.4 以降、Claude Code 以外のどのエージェントを優先するか。そのとき CLI を作るか（作るなら Python か Go か）
- [ ] marketplace と plugin の名前（案: どちらも specramo）
- [ ] 公開前の商標確認（J-PlatPat など）と GitHub の名前の確保

## Sources

- [github/spec-kit README](https://github.com/github/spec-kit)（2026-09-27 確認）
- [Claude Code Plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Claude Code plugin components](https://code.claude.com/docs/en/plugins/components)
- [Host a plugin marketplace](https://code.claude.com/docs/en/plugins/host-marketplace)
- [Plugins for organizations](https://code.claude.com/docs/en/plugins/org)
- [Kiro](https://kiro.dev/)、[Kiro IDE](https://kiro.dev/ide/)（検索結果の要約による。ページ本文は未確認）
