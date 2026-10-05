---
description: 実装から逆算した仕様書型の Design Doc を作る。振る舞いを受け入れ条件の表で固定し、/specramo:plan の入力にする。「Design Doc を作って」「設計書を作って」で使う。
argument-hint: "[機能名 | --update <path>] [--dry]"
disable-model-invocation: true
---

# /specramo:design - 実装から逆算した仕様書型 Design Doc

> **Goal**: Design Doc は、利用者から見える動きだけでなく、その変更を構成する外部 interface (Web API・画面・CLI・公開 API・event 等のうち該当するもの)・Read / Write・必要なシステム能力まで整理し、作業計画書で PR 単位の実装計画へ分解できる状態にする文書。作業計画書はその変更面を Phase = PR・層と責務・完了条件へ具体化する文書。file / method / SQL は `/specramo:phase-design` が決める。短く言えば「Design Doc = PR 分割できる粒度までシステム変更面を設計する文書、作業計画書 = その変更面を実装順と PR へ具体化する文書」。完成条件は「Design Doc だけを読んだ人が、実装詳細を知らなくても『何を作れば正解か』を判断できる状態」。


## Design Doc と作業計画書とPhase 詳細設計の境界 (正本)

| Design Doc に記載する | 作業計画書に記載する | `/specramo:phase-design` に記載する |
|---|---|---|
| 背景・課題 / 目的 / 要件 | Phase = PR と実装順序 | 変更 file / 関数・メソッド / 問い合わせ / 公開する契約 |
| 期待する振る舞い / 外部 interface・保存データ・UI の変更 (何が増え、何が変わるか) | 触る層とその責務 | 契約 / TX / 排他 |
| 制約 / 非対象 / Acceptance Criteria | 完了条件 (どの test で確かめるか) | test の実装方針 |
| 設計上の重要な決定 (利用者から見える動きが変わる決定) | 処理の置き場や共用の仕方 (見える動きは同じで作り方だけが変わる決定) | データ移行の手順 / code レベルの詳細 |

判定基準は「それが変わったとき利用者から見える動きが変わるか」。関数名や処理の分け方が変わっても見える動きが同じなら Design Doc の外側になる。ただし **method の「存在」は Design Doc、どの Phase で作るかは作業計画書、method の「実装形」はPhase 詳細設計**。「配送手続き中の注文が指定の配送オプションを使っているか判定する Read が必要」までは Design Doc に記載し、その method 名・SQL・呼び出し元は `/specramo:phase-design` が記載する。Design Doc に PR1 / PR2 のような分割は記載しない。

**Position**: 要件の `/specramo:prd`、仕様のこの command、Phase = PR 分割の `/specramo:plan`、Phase n の実装方法の `/specramo:phase-design` (省略可)、設計の説明の `/specramo:explain`、Phase 実装の `/specramo:implement`、Phase の review の `/specramo:review`、code の説明の `/specramo:explain` の順に進む。

> この command は大きい開発 (外部 interface (API / CLI / 公開関数 等) が増える / 保存データの形が変わる / 画面が 2 つ以上変わる) でだけ使う。小さな変更は Design Doc を作らずに直接実装する。

## 規範と雛形 (Read only)

着手前に、同梱した `writing-rules.md` (逆算の 4 原則、利用者が仕様を理解できる文章、構造ゲート) と Step 0 で決めた雛形を Read する。repo に独自の Design Doc の雛形を使いたいときは、導入先の `.specramo/templates/design.md` に置けば Step 0 がそちらを使う。

## Step 0: 前提確認と雛形の解決

1. 次の command を実行する。終了コードが 2 なら、表示をそのまま利用者に示して止まる。成果物は作らない。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/require-config.sh"
   ```

2. 雛形の path を決め、その file を読む。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-template.sh" design
   ```

3. 書き出し先は、設定 file の `specs_dir` の下の機能名の dir の `design.md` にする。引数の先頭の語が英小文字・数字・`-` だけなら、その語を機能名としてそのまま使い、言い換えない (後続の `/specramo:plan` などは利用者がその名前で path を指定する)。そうでなければ要件から英小文字と `-` の短い名前を決め、完了報告に dir の path を示す。同じ dir に `prd.md` があれば、Input interpretation の derive mode として読む。

## Input interpretation (ARGUMENTS からの自動分岐)

| Detection | Condition | Effect |
|------|------|------|
| update mode | 「`直して` / `更新` / `書き直し`」+ `.md` path | `--update <path>` 相当。既存の受け入れ条件の文を保ち、差分だけ Edit する。細則は `${CLAUDE_PLUGIN_ROOT}/skills/design/anatomy.md` 「update mode」 |
| derive mode | 同じ機能名の dir に `prd.md` がある、または「PRD から」「〜を元に」+ PRD `.md` path | PRD から導く。PRD の Q1-Q5 は再評価せず転記する。細則は `${CLAUDE_PLUGIN_ROOT}/skills/design/anatomy.md` 「derive mode」 |
| new mode | 上記なし | 通常 flow (Step 1 から) |

path があって fix keyword が無いときだけ、PRD から導くのか既存の Design Doc の更新なのかを 1 問で確かめる。それ以外は推奨の案で進め、その理由を 1 行で示す。

## Flow

着手前に `${CLAUDE_PLUGIN_ROOT}/skills/design/anatomy.md` を Read する。各 Step の細則はそこにある。

1. Input identify: 同じ dir の PRD > 機能名の引数 > `git log/diff` から推定する
   - 対象が特定できないときだけ 1 問
2. Load guidelines: 同梱した `writing-rules.md` と Step 0 の雛形を Read する
3. Analyze code: 既存の振る舞いと影響範囲を確かめる。Serena などの code 解析 tool があれば使い、無ければ grep で調べる
   - 最初に実装済みかを確かめ、要件がすでに実装されていれば Design Doc を書かずに実物の場所を報告して止まる
   - 論点ごとの確かめ方 (先例の数え方 / 同時実行の競合の防ぎ方 / 既存 endpoint の拡張 / 保存先と endpoint の実在) は anatomy 「Step 3: Analyze code の論点」に従う
3.5. Structure gate と骨子: draft 前に `writing-rules.md` の「文書全体の読みやすさ」を当て、見出しの役割と所有する主張を決める
   - 骨子を 1 画面で chat に示し、user の差分を待ってから本文へ進む
   - 骨子の内容と、待てない場合の代替は anatomy 「Step 3.5: 骨子の内容と待ち方」に従う
4. 受け入れ条件を先に記載する: Step 3 の結果と入力から、受け入れ条件を表で列挙する
   - DD には PRD に無い条件だけを記載し、PRD の条件は番号か条件文の引用で参照する
   - 表の列と番号の付け方は anatomy 「Step 4: 受け入れ条件の表の書き方」に従う
   - ここで user に「この条件で完了とみなしてよいか」を確かめる (最大 1 問、拮抗する条件があるときだけ)
5. 本文を逆算で埋める: spec template で記述する
   - 決定事項では毎回 3 論点を検討し、決定を追加する・変えるたびに Implementation Surface へ戻って表と合計 1 行へ追加する
   - どの受け入れ条件にも対応しない節は削る
   - 3 論点と節の削り方は anatomy 「Step 5: 決定事項の 3 論点と節の削り方」に従う
6. Quality gate: まず `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dd-gate.sh" <path>` を実行し、FAIL 0 まで修正する
   - script は合計と表の行数、未確定の残存、決定表の cell 長を判定する。WARN は理由を記載して削除せずにおいてよい
   - その後、下の **完了判定** を全て満たすまで Edit で修正する (最大 2 loop)
   - 満たせない項目は【要確認: 何を / 誰が決める / いつまで】として「未決事項」に集める
7. Write file: Step 0 で決めた path (`specs_dir` の下の機能名の dir の `design.md`) に書き出す
   - `--dry` は chat 表示のみ
7.5. writing check: `writing-rules.md` の「文章の自己点検」5 項目を file に当て、当たった箇所だけを書き換える (`--dry` は draft text)
7.6. 第三者 review: 内容を知らない読み手が理解できるかを 6 観点で確かめる
   - 書き手と別の context にするため、Claude Code の汎用のサブエージェントへ委譲し、1 回だけ実行する
   - 6 観点、prompt、指摘の扱いは anatomy 「Step 7.6: 第三者 review の実行者と指摘の扱い」に従う
8. Handoff: 次のコマンドを 1 行で案内する: `/specramo:plan`

## 完了判定 (Step 6 の gate = 作業計画書を作成する前のチェックリスト)

「作業計画書を作成する前に、何を作るかが十分に固定できているか」を確かめる。全項目を満たしたら Design Doc レビューに提出し、OK なら `/specramo:plan` に進む。1 つでも満たさなければ Step 4-5 に戻る。

**この gate が検査するのは、実装の振る舞いでなく要件の書かれ方だ**。

- 誤: 「一覧に 3 件表示されるか確認する」 — 実装を動かさないと判定できず、Design Doc の段階では答えが無い
- 正: 「表示件数と並び順が明示的に指定されているか」 — Design Doc の本文だけで判定できる
- 判定基準: 各項目が `Is X clearly specified?` の形に書き換えられるか。書き換えられない項目は実装の検査が含まれているので、作業計画書以降の gate へ渡す

| # | 項目 | 満たす状態 | script で確かめる方法 |
|---|---|---|---|
| 1 | 背景・課題 | なぜこの変更が必要か説明できる (PRD にあれば参照でよい) | — |
| 2 | 目的 | この開発で何を実現したいのか一文で言える。**誰の、どの状況が変わるのかを同じ 1 文に含める**。あわせて「この DD で決める範囲」を 1-2 文で記載し、レビュアーが見るものを最初に掴める | Overview の 1 文目に行為者 (運営 / 出品者 / 購入者 等) と状況が発生している。1 文目と 2 段落目 |
| 3 | 対象範囲 | 何を変更するのか分かる。Implementation Surface に API (種別 Read / Write、新規 / 既存拡張、責務)、必要な Read / Write の能力 (新規 / 既存)、画面 (FE 側の logic の有無)、保存データ (DB なら新規 table / 既存 table の列追加を 5 列表で、file / KVS なら保存単位ごとに) が表で整理され、作業計画書が PR 単位に分解できる | `${CLAUDE_PLUGIN_ROOT}/skills/design/anatomy.md` 「完了判定 #3: 対象範囲の判定方法」 |
| 4 | 非対象 | 今回やらないことが分かる。空にしない | Non-Goals が 1 行以上 |
| 5 | 期待する振る舞い | 正常系だけでなく主要な条件分岐 (境界 / 失敗時 / 同時実行 / 再送) も分かる。分岐のある場面は文章だけで説明せず、図か番号付き手順で示す | 各受け入れ条件に境界か失敗時の記述。`dd-gate.sh` の `behavior-diagram` (分岐のある受け入れ条件が 2 行以上あるのに振る舞いの節へ図も番号付き手順も無いと WARN。分岐語の検出は語彙に依存するため FAIL にしない) |
| 6 | Acceptance Criteria | 実装後に「完成した」と客観的に判定できる。「〜のとき、〜が〜になる」の形で、真偽が決まる | 各受け入れ条件に対応する振る舞いの節がある (本文に番号は書かない)。PRD と同じ条件を DD に書き換えていない |
| 7 | 外部から見える変更 | 外部 interface / 保存データ / UI の変更が整理され、変更が無い場合も「変更なし」と分かる | — |
| 8 | 既存仕様との関係 | 何を維持し、何を変えるのか明確 (PRD から変えた点は「PRD と違う点」と明記し、書き戻す) | 「PRD に書き戻す要件」の表 |
| 9 | 重要な設計判断 | 複数案があり得る部分について、どの方向にするか決まっている。却下案と理由がある。未確定事項 (Qn) に依存する決定は「暫定決定」と明記し、Qn と矛盾して見えないようにする | 設計判断の節 |
| 10 | 制約・前提条件 | 後方互換、性能、既存データ、リリース条件が書かれている。切替を伴うなら flag の型 (原則は code 定数型) と有効化 PR、撤去の条件が Release の節にある | 決定事項の「受け入れる制約」列、Release の節 |
| 11 | 実装方法に寄りすぎていない | 関数名、問い合わせ、file 名、処理の置き場、詳細な実装順序を記載していない。「読み取りの処理に存在確認を追加」「この問い合わせを使う」「この file を変更」はPhase 詳細設計 (`/specramo:phase-design`) 側で、作業計画書にも記載しない | `${CLAUDE_PLUGIN_ROOT}/skills/design/anatomy.md` 「完了判定 #11: 実装方法に寄りすぎていないかの判定方法」 |
| 12 | Design Doc だけで作業計画書を書き始められる | 「結局何を作るんだっけ」を追加確認しなくても作業計画に落とせる。未決事項は推奨を暫定決定として決定事項に置き、Open Questions の表は「暫定決定 / 再レビューの条件 / 確認先」だけを保持する。再レビューの条件の正本は Open Questions の表で、決定側には「暫定決定 (Qn)」と記載するだけにする (2 か所に記載すると片方だけ修正する) | `/specramo:plan` の入口判定 |
| 13 | 実装者が変わっても、作られるものの動きが変わらない | 人によって違うものを作る余地が小さい (判定に使う集合、主語と対象、決定の組み合わせが明記されている) | 用語節に集合の内外、各文に行為者と対象 |

一番重要なのは 11 〜 13 の 3 つ。良い状態は「何を作れば正解かは決まっている。どう作るかは作業計画書で決められる」、弱い状態は「作業計画書を書こうとすると要件や完成条件を再検討しないといけない」。

補助の判定 (上の表に含まれる細則):

- 「決定事項」に実装の書き方 (層 / 関数名 / 処理の置き場 / 共用の仕方) が混在していない (#11)
- 決定事項どうし、決定事項と受け入れ条件の組み合わせで結果が決まらない場面 (記録を消す × 再送、旧形式と新形式が両方来る) が無い (#13)
- 決定 n の本文に発生する名詞 (endpoint / flag / 一覧 / 別 table / master / 列) が Implementation Surface の表と Data Schema の table 一覧に記載されている。決定だけにあって表に無い endpoint や flag が無い。「master にする」と記載して表では固定値の列、のような不一致が無い (#13)
- 既存の制約 (一意 / 参照 / 必須 / 値の検査 / 排他制御) を削除または緩める変更では、Data Schema に「不変条件の担い手」の 5 列表 (最後の列は「確かめた箇所」) があり、Review Points に「同等のガードはあるか / なぜ付けていたか / どの操作で成り立たなくなるか」への答えが各 1 行である (#5 / #10。表が無いと、制約を消してよい理由をレビュワーに説明できない)
- 「参考にした既存実装」が 1 つ以上ある (#12)
- 「初回でやらないこと」に「後から追加するとき」の入口がある (#4)
- 「未確定事項」に番号と「決める時点 / 確認先」がある (#12)
- PRD に書かれている本文を繰り返していない (#8)
- 同じ内容が 2 つの節にない。振る舞いの節が受け入れ条件の表の言い直し、設計判断の節が決定事項の却下案の再掲、用語表が PRD の複製、になっていれば片方を消す。判定は節単位でなく概念単位で行い、1 つの概念 (例: サイズカテゴリー) の説明が本文 3 か所以上にあれば Glossary か決定の 1 か所に集約し、他は参照だけにする
- 暫定決定に置くのは、書き手が code や出典を読んでも決められない問い (確認先が運営 / 他 team / PRD author) だけ。既存の仕組みで扱えるかのような code を読めば決まる問いは Step 3 で決めて本決定にする
- 決定表の cell が 2 行を超えていない (超えるなら 箇条書き に戻す)
- 図は順序か分岐がある箇所だけにあり、label に `<br/>` が無い

## Options

| Option | Description |
|-----------|------|
| `--update <path>` | 既存 md を更新する (受け入れ条件の文を保ち差分だけ Edit) |
| `--dry` | file に書き出さず chat に表示する |

## Common guards

- 秘密情報 (API key、token、password) を記載しない。共有される文書に、個人の手元の path (`/Users/<名前>/...` など) を記載しない
- code 例は 5 行以内。1 file 1 H1。Mermaid は ``` mermaid code block
- 経過メモ (「当初 X で考えたが」) と時限マーカー (「この PR で」「先週」) を記載しない

## Bad Design Doc

受け入れ条件が無い / 「適切に処理する」で逃げる / 決定事項が実装の書き方になっている / 振る舞いが識別子の羅列で user に読めない → 実装の入力にならず、全て NG。

ARGUMENTS: $ARGUMENTS
