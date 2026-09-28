---
description: 作業計画書の Phase 1 つについて、既存 code を調べてから実装方法 (method / interface / SQL 方針 / TX / テスト観点) を決める。「詳細設計して」「Phase n の実装方法を決めて」で使う。
argument-hint: "[機能名] [--phase <n>]"
disable-model-invocation: true
---

# /specramo:phase-design - Phase 1 つの実装方法を決める

> **Goal**: 作業計画書の Phase n について、既存 code の事実を確かめてから実装形 (method / interface / 契約 / SQL 方針 / TX / 排他 / テスト観点) を決め、`/specramo:implement` がそのまま実装できる状態にする。実装はしない。

**Position**: 仕様の `/specramo:design`、Phase = PR 分割の `/specramo:plan`、Phase n の実装方法のこの command、設計の説明の `/specramo:explain`、Phase n の実装の `/specramo:implement` の順に進む。

## Step 0 の前: 前提確認と雛形の解決

1. 次の command を実行する。終了コードが 2 なら、表示をそのまま利用者に示して止まる。成果物は作らない。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/require-config.sh"
   ```

2. 雛形の path を決め、その file を読む。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-template.sh" phase-design
   ```

3. 作業計画書は、設定 file の `specs_dir` の下の機能名の dir の `plan.md` にある。

## なぜ作業計画書と分けるか

作業計画書には全 Phase 分が着手前に集まる。実装形まで記載すると、着手しない Phase の method 名と SQL まで読むことになる。作業計画書は「どの責務を、どの単位・順序で」の地図に保ち、実装形は着手する Phase の分だけこの file に格納する。

**分離の効果は限定的、行数削減は期待しない。**

- 作業計画書の中で実装形にあたる部分は、全体の 1 割程度にとどまる
- 効果は「着手する Phase 以外の実装形を読まずに済む」点と、次の段落の手戻りの防止になる

method 名・SQL・呼び出し元は既存 code を確かめないと妥当な形が決まらない。上流で決め打ちすると、調査結果と食い違ったときに作業計画書ごと書き換えることになるので、Phase に着手する直前に決める。

## When to use (棲み分け)

| Command | Use |
|---|---|
| `/specramo:plan` | Design Doc を Phase = PR に分ける。責務までを書き、実装形は書かない |
| `/specramo:phase-design <path> --phase <n>` | Phase n の実装形を決める (この command) |
| `/specramo:implement <path> --phase <n>` | Phase n を実装する。Phase 詳細設計があれば入力に取る |

「詳細設計して」「Phase n の実装方法を決めて」「実装前に調べて」で発火する。

## Step 0: 省略判定 (最初に行う)

次を全部満たす Phase はPhase 詳細設計を書かず、その旨を 1 行宣言して `Next: /explain <作業計画書 path> --phase <n>` (設計の説明を受けてから `/specramo:implement` へ) を記載して終える。**原則は書かない判断にする**。器があると埋めたくなるが、埋める価値の無い Phase で 1 file 増やすと、作業計画書肥大を場所を変えて繰り返すことになる。

- TX 境界 / 排他制御 / SQL の条件に判断の分岐が無い
- interface を新設しない (既存 interface の内部実装だけを変える)
- 作業計画書の 対象 / 対象外 / 完了条件 だけで実装形が一意に決まる

上の 3 条件は DB を扱う実装を想定した語彙なので、script / 定義 file / 文書だけの Phase では 1 つ目と 2 つ目が当たらない。その場合は 3 つ目 (完了条件だけで実装形が一意に決まるか) と、下の「未決の判断があるかどうか」で判定する。

判定するのは**未決の判断があるかどうか**であって、対象 file の数ではない。純粋な rename や一律の型の置換は、10 file に及んでも判断が無ければ省略する。逆に 1 file でも SQL の条件や TX 境界に選択肢があれば作る。

migration 単独の Phase と、既存 method の呼び出しだけで完結する Phase はこの条件に当たることが多い。

## Step 1: Phase の scope を読む

1. 引数の path を作業計画書として Read し、`--phase` の Phase 見出し 1 つだけを取る。`--phase` 省略時はPhase 詳細設計がまだ無い最初の Phase を選び、Phase 名を 1 行宣言する
2. その Phase の 目的 / 対象 / Read/Write / 対象外 / 完了条件 / 実装への指針 を scope として採用する。**他 Phase の内容を含めない**。作業計画書が 1 つの Phase を「PR 分割計画」と「実装計画」の 2 節に分けているときは、`grep -n "^### Phase <n>" <作業計画書>` で「実装計画」側の同じ Phase を探し、両方を合わせて scope とする
3. 「実装への指針」に列挙された repo 規範 (rule file) を Read する。列挙が無ければ、設定 file の `rules` に並べた file (未記入なら repo の `.claude/rules/` の file) から、この Phase の対象に当たるものを探す。**読む上限は 3 file** とし、この Phase の判断に当たるもの (TX なら database、排他なら concurrency、命名なら言語の rule) を優先する。全部読むと Phase 1 つの詳細設計に見合わない。命名 / 型 / 層 / error / test の制約は、この Step で読んだ rule が正本になる

## Step 2: Code Investigation (事実確認に徹する)

Phase の責務が **現在どこでどう実現されているか**を実物で確かめる。ここでは実装方法を決めず、事実だけを集める。

- 対象責務の現在地 (package / file / method)。Serena などの code 解析 tool があれば symbol 単位で調べ、file 全体は読まない。tool が無いか使えないときは `git grep -n` と `grep -n` で調べ、「code 解析 tool が無いため grep で調査した」と成果物に 1 行注記する
- 呼び出し元の一覧と件数 (`grep -rl` の file 数を数える)
- 依存する interface / 型 / 外部 API / DB
- 関連する既存 test の場所。あわせてその repo の test の書き方を 1 つ確かめ、file 名の規約と build tag と実行 command を転記する
- 変更時に注意が必要な箇所を確認する。JOIN 経由の参照、COUNT クエリ、cache、batch、非同期の処理、監査ログ、ORM の table 登録が対象になる
- table の行の意味が変わる変更 (物理削除から論理削除への切り替え、状態の値の追加など) では、table ごとに `bash "${CLAUDE_PLUGIN_ROOT}/scripts/table-readers.sh" <repo の root> <table 名>` を実行する。その出力を「実装メモ」の下の `### table を読む query` の節に、`table: <table 名>` の行に続けてそのまま記載する (末尾の「合計 n 件」も含める)。出力には、別の package や管理画面、batch の query も含まれる。条件の追加が必要な query は変更対象 file に含め、この Phase で扱わない query は作業計画書の対象外に記載する
- 作業計画書と実物の食い違い

**作業計画書 / Design Doc が名指しする既存の担保 (ロック / TX 境界 / 一意制約 / 状態遷移) は、その担保を取ると書かれた処理の入口から呼び出し順に確認して特定する**。`grep "FOR UPDATE"` の hit や file 名の一致で特定しない。同じ語を含む file が複数あると、別機能の担保を根拠にしたまま「記述と実物が食い違う」と判定することになる。確認した経路は `<入口の file:line> から <担保の file:line>` の形で 1 行記載する。

集めた事実は成果物の独立節にしない。実装の判断を変えるものだけを Step 3 の該当項目の下位 bullet に記載する。schema の列挙や呼び出し件数は、判断を変えないなら書かない。

**調査は AI が行ってよいが、結果の責任は実装担当者が負う**。返した method 一覧と件数は、採用する前に user が確認する前提で記載する。「AI が調べたから正しい」とはしない。

食い違いの扱いは `/specramo:plan` Step 2 の判定表に従う。endpoint / field / flag / table / 画面の不足や形の違いは `/specramo:design --update` へ戻す。Phase の切り方が変わる規模の食い違い (参照が 10 file を超える等) は `/specramo:plan --update` へ戻す。実装経路の詳細だけの違いはこの file に記載して進む。

## Step 3: 実装方法を決める

Step 2 の事実を踏まえ、**記載する価値のある項目だけ**を記載する。判断の無い項目は節ごと作らない (「変更なし」で節を埋めない)。

- 担当する受け入れ条件と、それを担う型 / 操作の対応 (作業計画書の完了条件が受け入れ条件を引用しているときだけ)。条件 1 行につき担い手を 1 つ書く。担い手が決まらない条件は実装形がまだ足りていないので、空欄のまま進めず Step 2 の調査へ戻る
- 対象 package / layer、Query か Command か
- interface と method (新設 / 既存の内部実装を変える / 既存の呼び出しを変える のどれか)。名前は Step 1 の repo 規範と、`${CLAUDE_PLUGIN_ROOT}/skills/implement/code-quality.md` 「Naming Criteria」の 3 基準と「Naming Shape」 (repo の語 / 平易な英語 / 削れる語は削る)、plugin の `guidelines/languages/` にある対象言語の開発指針に従う。根拠にした rule file 名と、基準 1 で数えた先例の件数を 1 行添える。本文には何をする method かを言葉で記載し、名前と根拠は「実装メモ」の表に記載する。これらの指針は Step 1 の 3 file 上限に数えない
- 入出力の型
- 処理フロー (順序か分岐があるときだけ、番号付きで)
- Transaction 境界 / 排他制御 (判断があるときだけ)
- DB 更新条件と SQL 方針。条件の付け方と付ける場所を書き、**SQL 全文は書かない**。JOIN 経由と COUNT にも同じ条件を付けるかどうかの判断をここで決める
- Validation / エラーハンドリング (既存のどの経路へ合わせるか)
- 既存処理との関係 (差し替え / 併存 / 呼び出し変更)
- 重複や不整合を防ぐ仕組みを別の仕組みに替えるとき (一意制約をやめて行ロックで防ぐなど) は、古い仕組みを前提にした code を列挙する。重複時の読み直し、409 の応答、失敗時の後始末が典型になる。新しい仕組みの下でその分岐に到達する入力があるかを 1 件ずつ判定し、到達しないものは削除する対象としてこの Phase に含める。到達する入力を 1 つも挙げられない分岐を、仮決定として保持しない
- 契約 (この Phase で型か公開 method を新しく作るときだけ)。**不変条件** (インスタンスが成立している間ずっと満たす条件) / **事前条件** (呼び出し側が満たす条件) / **事後条件** (正常終了時に提供側が保証すること) を 1 行ずつ書き、**それぞれをどこで守るかを添える** (constructor / factory / usecase / DB の制約)。単独の値の範囲は型の内側で守れるが、2 つの値の関係 (割引が元の価格を超えない等) と複数レコードの整合性は型の内側だけでは守れないので、守る場所を分けて書く
### テスト観点

完了条件の test をどう組むかと、mutation check で壊す条件を 1 つ決めておく。

- **fixture 条件**: fixture / test data を新規作成するなら、作業計画書の完了条件が引用する条件の数だけ区別できる行 (依頼 / レコード) を列挙する。複数の条件を同じ行で確かめるなら、それが区別不能な状態 (例: DB 上は同じ「対応する行が無い」状態になる) であることを理由として記載する。条件の数より行が少ないまま「fixture を 1 本追加する」とだけ記載すると、実装者はその記述だけでは完了条件を満たす test を作れない
- **mutation check**: 契約を記載した Phase では、3 条件のそれぞれに対応する test を 1 つずつ指す (1 対 1 で対応しないものは、その理由を 1 行記載する)
- 変更対象 file (Step 2 で実在を確かめたもの)。「実装メモ」の下に `### 変更対象 file` の見出しで箇条書きにする (`/specramo:implement` と `/specramo:review` がこの見出しを読む)
- 図を置くときは、同じデータの新旧 2 行など観測できる場面を中心にする。箱の label は「1件取得」「管理画面の件数」のように場面名にし、method 名と SQL 方針は「実装メモ」の表に記載する。関数名と SQL 条件を箱に記載した図は読み手が追えない
- 既存 PR があるときは計画を正とする。計画と PR の差は 1 節に留め、PR の SQL を調査メモへ転記しない

## 既存 detail file の rewrite (再発火 / 見た目の改善依頼)

同じ Phase について `/specramo:phase-design` が再発火する場面がある。command 更新後の再実行、または「図を追加したい」「表でなく平文にしたい」等の見た目の改善依頼が典型で、実装済みか未実装かにかかわらず起こる。

- 出力 file が既に存在するときは、上書き前に既存 file を Read し、記載済みの調査結果と判断を保つか削除するかを判定する。実装済み Phase の rewrite で調査結果を削除すると、着手時に既に決まった判断を書き換えることになる
- rewrite の主目的が「読み手が理解しやすい形にする」なら、実装判断の中身は保ちつつ、順序 / 図 / 見出しだけを差し替える。Code Investigation の独立節は置かない。判断そのものを書き換えるなら、既存判断を書き換える理由を冒頭に 1 行記載する
- 受け入れ条件を AC-N 番号で引用していた記述を平文へ書き換えるときは、番号を消すだけでは意味が失われる。作業計画書の完了条件の文言をそのまま引用して、担い手 (method / SQL / 排他) との対応を記載する
- 図を追加するときは観測できる場面を箱にする。経路の分岐が 3 本以上でも、method 名と SQL を箱に記載した図は置かない

## Step 4: 出力と handoff

- 出力先は作業計画書と同じ dir の `<作業計画書の basename から拡張子を除いた名前>-phase<n>.md`
- 冒頭は作業計画書の path と Phase 名。実装方法から始める。Code Investigation の独立節は置かない
- 本文は判断を言葉で書き、file 名 / method 名 / 行番号 / test の実行 command は末尾の「実装メモ」表 1 つに集める。表の行は本文の判断の番号と対応させる。変更対象 file の一覧もこの中の `### 変更対象 file` に置く。本文に識別子が並ぶと、読み手は判断より先に名前を読み解くことになり、判断が伝わらない。code comment の文面も書かない (実装時に決める)
- 分量は 100 行程度を目安にする。上限ではないので、超えるときは判断の無い節が残存していないかを 1 度確認し、削るものが無ければ超えてよい。目安を大きく超えるときは Phase 自体の大きさを疑い、`/specramo:plan --update` で Phase を割るかを検討する
- Next command を 1 行だけ記載する: `/specramo:explain <作業計画書 path> --phase <n>` (実装前に設計の説明を受け、その Next で `/specramo:implement` へ進む)。`/specramo:explain` と `/specramo:implement` は作業計画書と同じ dir だけを検索するので、出力先を変えない
- 書き出した後に `bash "${CLAUDE_PLUGIN_ROOT}/scripts/phase-gate.sh" <出力した file>` を実行し、FAIL 0 まで修正する。論理削除を扱う Phase で「table を読む query」の節が無いか、節の件数が改めて数えた件数と合わないと FAIL になる
- 実装に進まない

## Guard

- 実装しない。code を編集しない
- 作業計画書と Design Doc を編集しない。不足があれば `--update` の経路へ戻す
- 他 Phase の実装方法を先に決めない (1 回 1 Phase)
- **作業計画書が決めた件数 (参照箇所の数、削除するログの本数、対象 file の数) をPhase 詳細設計へ複製しない**。必要なときは作業計画書の節名で参照し、実装の判断に数が必要なら実物を再度数えて、数えた対象を 1 行記載する。複製した数は作業計画書の更新を反映せず、既存 PR の実装とも食い違う
- Step 2 の調査結果を「AI が確認済み」として扱わない。user の確認を前提に記載する
- 「未決」として記載するのは、入口からの呼び出し経路を 1 本確認しても決まらなかった項目だけにする。作業計画書 / Design Doc の記述と実物が食い違うと判定したときは、記載する前に、根拠にした箇所が対象の経路の内側にあるかを確認する
- 省略判定に当たる Phase で file を作らない

## Related

- `/specramo:plan` — 入力の作業計画書を作成する。Phase は責務までで、実装形は保持しない
- `/specramo:implement` — この file を入力に実装する
- `/specramo:design` 「完了判定」 #11 — 関数名 / SQL / file 名を Design Doc に置かない判定。行き先はこの skill
