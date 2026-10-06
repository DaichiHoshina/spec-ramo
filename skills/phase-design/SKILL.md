---
description: 作業計画書の Phase 1 つについて、既存 code を調べてから実装方法 (method / interface / SQL 方針 / TX / テスト観点) を決める。「詳細設計して」「Phase n の実装方法を決めて」で使う。
argument-hint: "[機能名] [--phase <n>]"
disable-model-invocation: true
---

# /specramo:phase-design - Phase 1 つの実装方法を決める

> **Goal**: 作業計画書の Phase n について、既存 code の事実を確かめてから実装形 (操作 / 契約 / 問い合わせの方針 / TX / 排他 / テスト観点) を決め、`/specramo:implement` がそのまま実装できる状態にする。実装はしない。

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

作業計画書は「どの責務を、どの単位・順序で」の地図に保ち、実装形は着手する Phase の分だけこの file に格納する。操作名・問い合わせ・呼び出し元は既存 code を確かめないと決まらないので、Phase に着手する直前に決める。**行数削減は期待しない**。理由と効果は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「なぜ作業計画書と分けるか」。

## When to use (棲み分け)

| Command | Use |
|---|---|
| `/specramo:plan` | Design Doc を Phase = PR に分ける。責務までを書き、実装形は書かない |
| `/specramo:phase-design <path> --phase <n>` | Phase n の実装形を決める (この command) |
| `/specramo:implement <path> --phase <n>` | Phase n を実装する。Phase 詳細設計があれば入力に取る |

「詳細設計して」「Phase n の実装方法を決めて」「実装前に調べて」で起動する。

## Step 0: 省略判定 (最初に行う)

次を全部満たす Phase は Phase 詳細設計を作らない。その旨を 1 行宣言し、`Next: /specramo:explain <作業計画書 path> --phase <n>` (設計の説明を受けてから `/specramo:implement` へ) を記載して終える。**原則は書かない判断にする**。

- TX 境界 / 排他制御 / 問い合わせの条件に判断の分岐が無い
- interface を新設しない (既存 interface の内部実装だけを変える)
- 作業計画書の 対象 / 対象外 / 完了条件 だけで実装形が一意に決まる

判定するのは**未決の判断があるかどうか**であって、対象 file の数ではない。永続化が絡まない Phase の判定と、省略に当たりやすい Phase の例は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「Step 0: 省略判定の考え方」にある。

## Step 1: Phase の scope を読む

1. 引数の path を作業計画書として Read し、`--phase` の Phase 見出し 1 つだけを取る。`--phase` 省略時は Phase 詳細設計がまだ無い最初の Phase を選び、Phase 名を 1 行宣言する
2. その Phase の 目的 / 対象 / Read/Write / 対象外 / 完了条件 / 実装への指針 を scope として採用する
   - **他 Phase の内容を含めない**
   - 「PR 分割計画」と「実装計画」の 2 節に分かれた作業計画書は両方を合わせて scope とする。探し方は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「Step 1: scope と repo 規範の読み方」
3. 「実装への指針」に列挙された repo 規範 (rule file) を Read する
   - 列挙が無ければ、設定 file の `rules` に並べた file (未記入なら repo の `.claude/rules/` の file) から探す
   - **読む上限は 3 file** とし、この Phase の判断に当たるものを優先する。命名 / 型 / 層 / error / test の制約は、ここで読んだ rule が正本になる

## Step 2: Code Investigation (事実確認に徹する)

Phase の責務が **現在どこでどう実現されているか**を実物で確かめる。ここでは実装方法を決めず、事実だけを集める。

- 対象責務の現在地 (module / package / file / 操作)。Serena などの code 解析 tool があれば symbol 単位で調べ、file 全体は読まない。tool が使えないときの代替は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「code 解析 tool が使えないとき」
- 呼び出し元の一覧と件数 (`grep -rl` の file 数を数える)
- 依存する interface / 型 / 外部 API / DB
- 関連する既存 test の場所。あわせてその repo の test の書き方を 1 つ確かめ、file 名の規約と test の実行条件 (tag や環境変数) と実行 command を転記する
- 変更時に注意が必要な箇所を確認する。他の table を経由する参照、集計、cache、batch、非同期の処理、監査ログ、永続化層の登録が対象になる
- 保存データの行や状態の意味が変わる table があるかを確かめる。物理削除から論理削除への切り替え、状態の値の追加、既存の列の意味の変更などが当たる。Phase 名の直後に `意味が変わる table: <table 名 (カンマ区切り)>` か `意味が変わる table: なし` の 1 行で宣言する。ある場合は、その保存先を読む処理を `table-readers.sh` と grep で全部洗い出し、`### table を読む query` の節に処理ごとの `- 扱い:` の行と一緒に記載する。手順と行の形は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「保存データの意味が変わるときの洗い出し」
- 作業計画書と実物の不一致

**作業計画書 / Design Doc が名指しする既存の担保 (ロック / TX 境界 / 一意・外部キー・NOT NULL 等の制約 / 状態遷移) は、処理の入口から呼び出し順に確認して特定する**。grep の hit や file 名の一致で特定しない。記載の形は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「既存の担保の特定」。

集めた事実は成果物の独立節にしない。実装の判断を変えるものだけを Step 3 の該当項目の下に記載する。結果は user の確認を前提に記載する (`${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「集めた事実の扱い」)。

不一致の扱いは `/specramo:plan` Step 2 の判定表に従う。

| 不一致の種類 | 戻り先 |
|---|---|
| endpoint / field / flag / table / 画面の不足や形の違い | `/specramo:design --update` |
| Phase の切り方が変わる規模 (参照が 10 file を超える等) | `/specramo:plan --update` |
| 旧経路と新経路が code 上で並存する置き換えの Phase で見つかった後片づけ (到達しなくなる分岐 / 不要になる test・fixture) | `/specramo:plan --update` |
| 実装経路の詳細だけの違い | この file に記載して進む |

## Step 3: 実装方法を決める

Step 2 の事実を踏まえ、**記載する価値のある項目だけ**を記載する。判断の無い項目は節ごと作らない (「変更なし」で節を埋めない)。各項目の決め方は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「Step 3: 項目ごとの決め方」の同名の節にある。

- 担当する受け入れ条件と、それを担う型 / 操作の対応 (作業計画書の完了条件が受け入れ条件を引用しているときだけ)
- 対象の構成単位 / 層、参照か更新か
- 公開する契約 (interface / 関数 / method) と、その名前の根拠
- 入出力の型
- 処理フロー (順序か分岐があるときだけ、番号付きで)
- Transaction 境界 / 排他制御 (判断があるときだけ)
- 保存データの更新条件と問い合わせの方針。条件の付け方と付ける場所を書き、**問い合わせの全文は書かない**。他の table を経由する読み取りと集計にも同じ条件を付けるかどうかの判断をここで決める
- Validation / エラーハンドリング (既存のどの経路へ合わせるか)
- 既存処理との関係 (差し替え / 併存 / 呼び出し変更)
- 重複や不整合を防ぐ仕組みを替えるときの、古い仕組みを前提にした分岐の扱い
- API の応答を増減させるときの API 仕様の変更
- 契約 (この Phase で型か公開する操作を新しく作るときだけ)。**不変条件** / **事前条件** / **事後条件**と、それぞれを守る場所
- テスト観点 (下の節)
- 変更対象 file (Step 2 で実在を確かめたもの)。「実装メモ」の下に `### 変更対象 file` の見出しで箇条書きにする (`/specramo:implement` と `/specramo:review` がこの見出しを読む)
- 図を置くときは、観測できる場面を箱にする (`${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「図の置き方」)
- 既存 PR があるときは計画を正とする。計画と PR の差は 1 節に留め、PR の問い合わせを調査メモへ転記しない

### テスト観点

完了条件の test をどう組むかと、mutation check で壊す条件を 1 つ決めておく。次の 3 点の決め方は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「テスト観点」にある。

- **fixture 条件**: 完了条件が引用する条件の数だけ、区別できる行を列挙する
- **扱いを検証する fixture**: 「扱い: 変更する」と決めた処理ごとに、意味が変わった行を含む fixture を記載する
- **mutation check**: 契約を記載した Phase では、3 条件のそれぞれに対応する test を 1 つずつ指す

## 既存 detail file の rewrite (再実行 / 見た目の改善依頼)

同じ Phase について `/specramo:phase-design` を再実行する場面がある。command 更新後の再実行、または「図を追加したい」「表でなく平文にしたい」等の見た目の改善依頼が典型で、実装済みか未実装かにかかわらず起こる。

- 出力 file が既に存在するときは、上書き前に既存 file を Read し、記載済みの調査結果と判断を保つか削除するかを判定する。実装済み Phase の rewrite で調査結果を削除すると、着手時に既に決まった判断を書き換えることになる
- rewrite の主目的が「読み手が理解しやすい形にする」なら、実装判断の中身は保ちつつ、順序 / 図 / 見出しだけを差し替える。Code Investigation の独立節は置かない。判断そのものを書き換えるなら、既存判断を書き換える理由を冒頭に 1 行記載する
- 受け入れ条件を AC-N 番号で引用していた記述を平文へ書き換えるときは、番号を消すだけでは意味が失われる。作業計画書の完了条件の文言をそのまま引用して、担い手 (操作 / 問い合わせ / 排他) との対応を記載する
- 図を追加するときは観測できる場面を箱にする。経路の分岐が 3 本以上でも、操作名と問い合わせを箱に記載した図は置かない

## Step 4: 出力と handoff

1. 出力先は作業計画書と同じ dir の `<作業計画書の basename から拡張子を除いた名前>-phase<n>.md`
2. 構成を次のとおりにする
   - 冒頭は作業計画書の path と Phase 名。実装方法から始める。Code Investigation の独立節は置かない
   - Phase 名の直後に `意味が変わる table:` の 1 行を置く (Step 2)
   - 本文は判断を言葉で書き、file 名 / 操作名 / 行番号 / test の実行 command は末尾の「実装メモ」表 1 つに集める。表の行は本文の判断の番号と対応させる。変更対象 file の一覧もこの中の `### 変更対象 file` に置く。code comment の文面も書かない
   - 分量は 100 行程度を目安にする (超えるときの判断は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「Step 4: 出力の細則」)
3. Next command を 1 行だけ記載する: `/specramo:explain <作業計画書 path> --phase <n>` (実装前に設計の説明を受け、その Next で `/specramo:implement` へ進む)。出力先は変えない
4. 書き出した後に `bash "${CLAUDE_PLUGIN_ROOT}/scripts/phase-gate.sh" <出力した file>` を実行し、FAIL 0 まで修正する。FAIL になる条件は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「Step 4: 出力の細則」
5. 実装に進まない

## Guard

- 実装しない。code を編集しない
- 作業計画書と Design Doc を編集しない。不足があれば `--update` の経路へ戻す
- 他 Phase の実装方法を先に決めない (1 回 1 Phase)
- **作業計画書が決めた件数 (参照箇所の数、削除するログの本数、対象 file の数) を Phase 詳細設計へ複製しない**。理由と代わりの記載方法は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「禁止事項の理由」
- Step 2 の調査結果を「AI が確認済み」として扱わない。user の確認を前提に記載する
- 「未決」として記載するのは、入口からの呼び出し経路を 1 本確認しても決まらなかった項目だけにする (記述と実物の不一致を判定するときの確認は `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` 「禁止事項の理由」)
- 省略判定に当たる Phase で file を作らない

## Related

- `/specramo:plan` — 入力の作業計画書を作成する。Phase は責務までで、実装形は記録しない
- `/specramo:implement` — この file を入力に実装する
- `/specramo:design` 「完了判定」 #11 — 関数名 / 問い合わせ / file 名を Design Doc に置かない判定。行き先はこの skill
- `${CLAUDE_PLUGIN_ROOT}/skills/phase-design/anatomy.md` — 各 Step の細則
