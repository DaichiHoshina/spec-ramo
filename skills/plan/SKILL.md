---
description: Design Doc から作業計画書 (Implementation Plan) を作る。Phase を意味で分けて 1 Phase = 1 PR にし、各 Phase に対象 / 対象外 / 完了条件を記載する。「作業計画書を作って」「PR 構成を決めて」で使う。
argument-hint: "[機能名 | 要件の 1 文] [--phases <n>] [--update]"
disable-model-invocation: true
---

# /specramo:plan - Design Doc から作業計画書を作る

> **Goal**: 実装前に作業を意味のある単位 (Phase = PR) に分け、各 Phase を読めば「何を作れば完了か」が分かる作業計画書を 1 file 作る。実装はしない。**分割の判断はレビューのしやすさを最優先にする** (Step 3 「分割の優先順位」)。

## When to use (棲み分け)

| Command | Use |
|---|---|
| `/specramo:design` | 実装から逆算した仕様書型 Design Doc (受け入れ条件の表と決定事項) を作る。この command の入力 |
| `/specramo:plan` | Design Doc を実装単位 (作業計画書) に分け、PR 構成と完了条件を決める。責務までを記載し、実装形は記載しない |
| `/specramo:phase-design` | Phase n の実装形 (公開する型と操作 / 問い合わせの方針 / TX / テスト観点) を、既存 code の調査から決める。単純な Phase では省く |
| `/specramo:implement` | 作業計画書の Phase n だけを実装する |

Design Doc を作る線引き (外部 interface が増える / 保存データの形が変わる / 画面が 2 つ以上変わる) に当たらない小さな変更は、Design Doc なしで要件の 1 文から直接この command に入ってよい。

## Step 0: 前提確認と雛形の解決

1. 次の command を実行する。終了コードが 2 なら、表示をそのまま利用者に示して止まる。成果物は作らない。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/require-config.sh"
   ```

2. 雛形の path を決め、その file を読む。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-template.sh" plan
   ```

3. 書き出し先は、設定 file の `specs_dir` の下の機能名の dir の `plan.md` にする。同じ dir の `design.md` を入力の Design Doc として読む。

## Step 1: 入力の特定

- `--update` (または `作業計画書を直して` `反映して` と既存の作業計画書) のときは全体を再生成せず、影響する Phase だけを Edit する
- plugin を更新した後の既存の作業計画書も再生成しない。作業計画書の検査 (Step 4) を適用して FAIL と WARN の項目だけを Edit する
- 運用の詳細は同梱の `phase-anatomy.md` 「`--update` の運用」

1. Design Doc を Read する。「受け入れ条件」の表を最初に取り、Phase 分割の材料にする。条件は ID を保持しないので、先頭 20 字程度を引用して指す。各条件をどの test (API test / CLI の結合 test / unit test / 手動 等、repo にある種類) で確かめるかは Design Doc に無いので、この command が Phase の完了条件として決める
2. Phase の候補は Design Doc の Implementation Surface (API / Read / Write / 画面 / Interfaces の表のうち DD にあるもの) から取り、各行をどの Phase に割り当てるかをこの command で決める。
   - 操作名・問い合わせ・呼び出し元はここで決めず、`/specramo:phase-design` が Phase ごとに決める。method の存在は Design Doc が、どの Phase で作るかは作業計画書が、実装形は Phase 詳細設計が決める
   - 500 行を超える Design Doc は全文を読まず、見出しの一覧から範囲・目標・非目標・外部 interface の一覧・保存データの設計・UI の変更・リリース計画・既存の不具合の修正の節だけを読む
   - 1 文の要件なら、それを「目的」に置き、Design Doc の欄は「未作成」と記載する
3. 雛形の節を勝手に減らさず、記載することが無い節は「該当なし」1 行にする。進捗の記録のように実装前には埋められない節は、見出しと「実装中に記入」の 1 行だけにする

**入口の判定 (Design Doc が作業計画書を作れる状態か)**: `/specramo:design` の「完了判定」の 13 項目を Design Doc に当てる。

- 満たさない項目があれば Phase 分割に入らず、「Design Doc との差分」に記載して `/specramo:design --update` へ戻す
- 特に #12 (Design Doc だけで作業計画に落とせるか) と #13 (実装者が変わっても、作られるものの動きが変わらないか) を満たさない Design Doc から Phase を分けると、Phase ごとに要件を再検討することになる
- あわせて Open Questions (未確定事項) の「決める時点」を確かめる。「作業計画書の作成前」「DD レビュー」の問いが未決のままなら Phase を分けず、問いと確認先を chat に示して止まる

## Step 2: 影響範囲を実物で確かめる

Design Doc が無い 1 文の要件で入ったときは、他の手順より先に**要件がすでに実装されていないか**を確かめる。

1. 要件に登場する名詞 (script 名 / 機能名 / 保存先の名前 / command 名) を語にして `git grep -l` と `ls` を実行する
2. 実在したものは新規作成の Phase にせず、「既存実装の確認」の節に file 名と行数と test の有無を記載する。Phase は残りの差分だけで分ける

Design Doc に記載された API / Query / Command / 画面ごとに、既存 code の置き場所を検索し (Serena などの code 解析 tool があれば使い、無ければ grep)、対象の file と test の file を並べる。

- **並べたら、1 件ずつ production の呼び出し経路から到達するかを確かめる**
- 語句の検索に一致するだけの箇所 (production から呼ばれない method や、別機能の同名の処理) を対象に含めると、到達しない code へ条件を追加する Phase を作ることになる
- 到達しない箇所は対象から除き、その理由を 1 行記載する

### Change Map (影響範囲の先頭に置く)

**Change Map は、システムの構造の中で今回どこを変更し、どこを変更しないかを示す表とする**。層ごとに 1 行を置き、変更しない層も行にして、`変更` 列で変更の有無を示す。変更しない層も記載することで、「記載の欠落」と「確認したうえで変更不要」を区別できる。

実行時の呼び出し経路と同じにする必要は無い。起動時の設定や型の定義のように、実行時には通過しないが変更が波及しうる箇所も行にしてよい。3 つの図表の役割は次のとおりで、重ならないようにする。

| 図 | 何を表すか | 置き場 |
|---|---|---|
| 振る舞いの図 | 実行時の振る舞い | Design Doc の振る舞いの節 |
| Change Map | 変更が波及する構造 | 作業計画書の `影響範囲` |
| マージ順序の図 | 実装と merge の順序 | 作業計画書の `マージ順序と依存関係` |

列と行の書き方は同梱の `phase-anatomy.md` 「Change Map の表の書き方 (Step 2)」を Read する。

個別の判定は同梱の `scope-scan.md` を Read する。扱うのは、参照件数と Phase の配置、Data Schema の不変条件、永続化層への登録、生成物の差分、test file の実在の確認、画面の repo の特定、Design Doc と code の不一致の扱い、作られなくなる状態を読む側の 8 つ。

## Step 2.5: repo の規約を Phase に当てる

repo の規約の file を Phase ごとに当て、該当する規約を「実装への指針」に記載する。

- 規約の file: 設定 file の `rules` に並べた file。未記入なら repo の `.claude/rules/` の file。どちらも無ければ「該当 rule なし」として進む
- 記載の形・規約が当たるときの扱い・path の例外は、同梱の `phase-anatomy.md` 「Step 2.5 repo 規範の引き当て」を Read する

## Step 3: Phase を意味で分ける

Phase 分割の前に、Design Doc の主要な操作ごとの処理の順序を「処理フロー」節に番号付きで記載する (Phase の対象・依存関係・Read/Write の洗い出しの元にする)。変わる手順には Change Map と同じ `★` を付け、担当 PR を 1 行で添える。変わらない手順も記載し、印の有無で「確認したうえで変更なし」を区別する。

**分割の優先順位**: 本番を壊さない merge の順序は前提条件で、その範囲の中でレビューのしやすさを最優先に分ける。判断が競合したら上の項目を採り、下の項目を諦めた理由を PR 分割計画に 1 行記載する。

1. **reviewer がその PR だけで採否を決められる**。diff と PR 本文だけで正しさを判断でき、他の PR の diff を開いたり実装者に意図を聞いたりせずに済む
2. **1 PR = 1 目的で、変更行数が小さい**。test を除いて上限は設定 file の `max_lines` (初期値 400)、目安はその半分にする。目的の違う変更 (機能の追加と既存の不具合の修正、実装と rename) を 1 本の PR に同居させない
3. **reviewer が見慣れた形にそろえる**。層切りか縦切りか、既存挙動を変えない PR への印の付け方は repo の慣習に合わせる。慣習どおりに分けると 1 か 2 を満たせないときだけ慣習から離れ、離れた理由を記載する
4. **実装の作りやすさ**。上の 3 つを満たす分け方が複数あるときの決め手にする

Phase が 3 つ以上になったら、同梱の `purpose-traceability.md` に従い「目的と実装の対応」を作る (2 つ以下なら作らない)。作る条件と形、Mermaid の図を作らない理由は `phase-anatomy.md` 「目的と実装の対応の書き方 (Step 3)」。

分け方の規則は次の 3 群に分かれる。

- **順序と単位**
  - Design Doc にリリース計画 (DB、管理画面、ユーザーの画面のような段階) があれば、Phase の順序はそれに従う。無ければ「merge しても本番が壊れない順」で並べる
  - 旧経路と新経路が code 上で並存する置き換えでは、PR 分割計画を最初から「リリースする PR 群」と「切り戻しの期間の後に merge する削除の PR 群」の 2 群で組む。旧経路と、旧経路を前提にした code・test・fixture の削除は後者に置き、リリース後も切り替えの PR だけを revert して旧経路へ戻せるようにする。細則は同梱の `phase-anatomy.md` 「リリース後の削除の PR 群」を Read する
  - 状態を作らなくする PR (不変条件の追加 / 登録経路を 1 本にする / 旧経路の撤去) があるとき、その状態を読む code の分岐・test・fixture を列挙し、削除する PR か削除しない理由に割り当てる。手順は `scope-scan.md` 「作られなくなる状態を読む側」、割り当ては `phase-anatomy.md` 「作られなくなる状態の読み手と PR の割り当て」に従う
  - 1 Phase = 1 PR。BE と FE が別の repo のときは Phase を共通にし、repo ごとに PR 1 本ずつとする (PR 分割計画に repo を記載する)。Phase 名は「サイズ取得機能を追加する」のように、merge 後に利用者か運用者ができることで記載する
  - Design Doc の範囲に「既存の不具合の修正」が同居していれば、利用者から見える挙動が別なので独立した Phase にし、新機能の Phase より前に置く
  - `--phases <n>` は上限であって目標ではない。意味の単位が n 未満ならそのまま少なく作る
- **縦切りと層切り**
  - 分け方は優先順位 3 に当たるので、repo の慣習を先に測って決める。同じ機能領域の直近の merged PR を `gh pr list --search "<issue 番号か機能名>" --state merged` で 5 本程度取得し、title と diff の層 (モデルの層だけ / 業務処理の層と外部接続の層だけ 等) を確かめる。層で追加する慣習なら層切りを基本にし、慣習が無い repo だけ縦切りを基本にする
  - 層で追加する慣習で dead code first の雛形が使える repo は、同梱の `phase-anatomy.md` の「Dead code first 雛形」を Read する
  - **PR 分割計画の冒頭に flag の判断を 1 行記載する**。雛形を採るなら `- flag: <flag 名> (配線 PR で OFF、有効化 PR で ON)`、採らないなら `- flag: 使わない (理由: <1 文>)`。作業計画書検査の behavior 判定は、「変わる」が 3 本以上のとき、この行の内容で FAIL と WARN を分ける
  - 縦切りを基本にした場合、型だけ / 問い合わせだけ / 処理の本体だけ の層切りは、`phase-anatomy.md` 「縦切りを基本にした場合の層切り例外」の条件をすべて満たすときだけ許す
- **PR の見出しと記載**
  - **PR の見出しは `### PR #N: [Phase 名]` だけにする**。依存 / branch / 既存挙動 / 想定変更行数は、見出しの直下の箇条書きに 1 項目 1 行で記載する
  - PR の見出し 1 つに、目的 / 対象 / Read/Write / 対象外 / 完了条件 / 実装への指針 / 動作確認手順 を直下に記載する。対象は層と責務の mermaid 図にし、PR 本文の「責務」「変更箇所と責務」へ転記する。各項目の書き方は `phase-anatomy.md`。Phase 名は対象を目的語にした 1 文にする
  - Phase が 3 つ以上なら、PR 分割計画に依存の向きとマージ順序を記載する。依存の書き方は同梱の `pr-chain.md` に従う
  - PR 分割計画の各 PR に「想定変更行数 (test 抜き)」を記載する。Step 4 の行数の点検はこの値でし、値が無い計画書は点検できていない扱いにする。見積もりの規則は `phase-anatomy.md`

Design Doc に「不変条件の担い手」の表があるとき (制約を削除するか緩める変更) は、「削除・緩和した後の担い手」を実装する Phase を同じ計画書に置き、制約を削除・緩和する Phase (NOT NULL の列を nullable に変える、CHECK の範囲を広げる 等を含む) との前後関係をマージ順序の節に記載する。**原則は担い手を先に merge する順序にする**。順序ごとの記載の仕方は同梱の `phase-anatomy.md` 「削除・緩和した後の担い手と merge 順序 (Step 3)」を Read する。

## Step 4: 自己点検

書き出した後に作業計画書検査を実行し、FAIL が 0 件であることを確かめる。検査するのは、各 PR の想定変更行数、上限超えの分割しない理由、branch 名、実装形の混入。branch 名の形まで判定するのは設定 file に `branch_pattern` があるときだけで、無ければ名前があるかだけを判定する。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/spec-gate.sh" <作業計画書の path>
```

FAIL が 0 件になったら、同梱の `phase-anatomy.md` 「自己点検の項目 (Step 4)」を Read し、全項目を満たすか確かめる。1 つでも満たさなければ Step 3 に戻る。

## 記載しないこと

作業計画書は、読み手 (実装者と reviewer) が PR ごとの判断に必要な分だけにする。次の 4 種は記載せず、作業計画書の冒頭に「この計画書に記載しないこと」として同じ 4 行を置く。4 種の範囲は同梱の `phase-anatomy.md` 「記載しないこと (4 種の範囲)」を Read する。

- 他の文書に正本がある内容
- file path、関数・method 名、問い合わせ、fixture の構成
- 同じ内容の 2 回目以降
- 決定した日付と経緯

## Step 5: 出力と handoff

- 作業計画書を Step 0 の path に書き出し、path を chat に示す。冒頭に PR の数と目安の日程を記載し、チームに共有する文を chat に 3 行以内で示す
- 「Phase の状態」の表に、PR ごとの行を追加する。PR 列は `#<番号>`、Phase 名は PR の見出しの Phase 名、状態は「未着手」、説明は空にする
- 次のコマンドを 1 行で案内する: `/specramo:phase-design` (省略判定に当たる Phase なら `/specramo:explain`)
- 実装には進まない

## Read-only (作業計画書以外)

記載するのは作業計画書 1 file だけで、code / Design Doc を編集しない。Design Doc に不足があれば「Design Doc との差分」に記載して利用者に戻す。
