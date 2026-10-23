---
description: 鎖の各 skill の出口で使う。PRD / Design Doc / 作業計画書 / Phase 詳細設計は、次の skill に必要な情報が揃っているかを確かめる (引き継ぎ確認)。/specramo:implement で実装した Phase 1 つの差分は、設計書との比較・過去の指摘・repo の規約・言語の開発指針の観点で並列に review し、結果で Phase の状態を進める。「Phase をレビューして」「PRD / Design Doc / 作業計画書をレビューして」で使う。
argument-hint: "[機能名 | 成果物 path] [--phase <n>] [--fix]"
disable-model-invocation: true
---

# /specramo:review - Phase の差分を review する

> **Goal**: `/specramo:implement` が実装した Phase n の差分を観点ごとに別のエージェントで review し、利用者が `/specramo:explain` で差分を理解する前に、修正するものを確定させる。結果の Critical と Warning の合計で Phase の状態を進める。

**Position**: 鎖の各 skill の次に毎回置く。`/specramo:prd`、`/specramo:design`、`/specramo:plan`、`/specramo:phase-design` の次は引き継ぎ確認、`/specramo:implement` (Phase の実装) の次は差分の review になる。各 skill は出口でこの skill を続けて実行する。差分の review で修正するものが無くなったら `/specramo:explain` (code の説明) から PR へ進む。

## 引き継ぎ確認か差分の review かの判定

引数と branch から自動で決める。mode を指定する option は無い。

| 入力 | 行うこと |
|---|---|
| `prd.md` / `design.md` / `plan-phase<n>.md` の path | 引き継ぎ確認 |
| `plan.md` の path か機能名で、`--phase` が無く、現在の branch が作業計画書のどの Phase の `branch:` 行とも一致しない | 引き継ぎ確認 (作業計画書) |
| それ以外 (`--phase` がある、または branch が Phase に一致する) | 差分の review (Step 0 以降) |

## 引き継ぎ確認

成果物が、次の skill の入力として足りているかを確かめる。この確認では差分の review の Step 1〜6 を実行せず、code の差分も読まない。

確認の対象 (成果物と前の段の成果物) は、この確認の時点で Read し直す。会話の前半で読んだ内容や要約を比べる基準にしない。

1. 成果物を Read し、`${CLAUDE_PLUGIN_ROOT}/skills/review/handoff.md` を Read して、成果物の種類に当たる行と、その節の項目を採る
2. その行に script があれば、この skill を実行している側が実行する。script が判定する項目は結果をそのまま使う
3. 表の「判断で確かめる項目」を 1 項目ずつ、成果物の節名と引用で「揃っている / 不足 / 未確認」に分ける。引用できない項目は「不足」にする
4. 作業計画書と Phase 詳細設計の確認では、前の段の成果物 (同じ dir の `design.md` / `plan.md`) を Read し、受け入れ条件と Implementation Surface の割り当ての抜けを突き合わせる。前の段の成果物が無いときは「未確認」にする
5. 出力は 1 行目に結論を置く。続けて不足と未確認の項目だけを「項目 / 理由 / 戻す先」の表にして示す。揃っている項目は件数だけにする。保存はせず chat だけで返す

   ```
   specramo:review 引き継ぎ確認: <成果物の種類> — <次の skill> に進める / 進めない (不足 <n> 件、未確認 <m> 件)
   ```

6. Next を 1 行記載する。不足があれば作った skill へ戻し、無ければ次の skill へ進む

| 成果物 | 不足が 0 件のときの Next | 不足があるときの Next |
|---|---|---|
| PRD | `/specramo:design <機能名>` | `/specramo:prd <機能名>` (不足の項目を指定して更新) |
| Design Doc | `/specramo:plan <機能名>` | `/specramo:design --update <design.md の path>` |
| 作業計画書 | `/specramo:phase-design <機能名> --phase 1` (省略判定に当たる Phase は `/specramo:explain <機能名> --phase 1`) | `/specramo:plan --update <機能名>` (受け入れ条件の欠落が Design Doc 側の誤りなら `/specramo:design --update <design.md の path>`) |
| Phase 詳細設計 | `/specramo:explain <機能名> --phase <n>` | `/specramo:phase-design <機能名> --phase <n>` (作業計画書の誤りなら `/specramo:plan --update`) |

未確認の項目だけが不足の代わりに挙がったときは、未確認の項目を示して「進める / 戻す」の推奨を 1 つ添える。

引き継ぎ確認では成果物を編集しない (不足は作った skill へ戻して修正する)。次の skill を自動で起動しない。

## Step 0: 前提確認

次の command を実行する。終了コードが 2 なら、表示をそのまま利用者に示して止まる。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/require-config.sh"
```

作業計画書は、設定 file の `specs_dir` の下の機能名の dir の `plan.md` にある。

## Step 1: 入力

作業計画書・Design Doc・PR 本文・issue は、この review の時点で取得し直す。会話の前半で読んだ内容や要約を比べる基準にしない。

1. 作業計画書を Read する。`--phase` 省略時は、現在の branch 名を作業計画書の各 PR の `branch:` 行と照合して Phase を特定し、Phase 名を 1 行宣言する。一致が無ければ「Phase の状態」の表で「実装中」の最初の行を採用する。
2. Phase の 対象 / 対象外 / 実装への指針 を読む。作業計画書冒頭の `- Design Doc:` 行に path があれば、その Design Doc の受け入れ条件の表も読む。同じ dir に Phase 詳細設計 `plan-phase<n>.md` があれば、`### 変更対象 file` と契約の節を読む (冒頭に「無効」とあるものは使わない)。
3. 作業計画書が Phase を複数の PR に分ける条件を定めているときは、review の範囲を分割後の PR に合わせる。後ろの PR へ回った作業は「対象外 (後続 PR で対応)」として全エージェントの prompt に渡す。
4. 差分の base を決める。作業計画書の `依存:` にある前 Phase の branch が未 merge ならその branch、merge 済みか依存なしなら default branch とし、`git merge-base` の結果を 1 行記載する。`/specramo:implement` は commit しないので、差分は merge-base から作業ツリーまで (未 commit の変更と未追跡の file を含む) とする。commit 済みの差分も作業ツリーの変更も無いときだけ「review 対象なし」で終える。

## Step 2: 起動するエージェントを決める

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/select-review-agents.sh" . $(git diff --name-only <merge-base>) $(git ls-files --others --exclude-standard)
```

2 番目以降の引数は差分の file 名で、D に渡す開発指針を拡張子で決める (対応は `guidelines/languages/extensions.tsv`。表に行が無い言語では開発指針なしで D を起動する)。表示は 1 行 1 エージェントの tab 区切りで、`run` か `skip` と、渡す値か省いた理由が並ぶ。`warn` の行は C の規約の path が存在しない警告になる。

- `skip` の行の理由と `warn` の行は、そのまま利用者に表示する
- 起動するのは `run` の行のエージェントだけにする。この表示と異なる判断で起動したり省いたりしない

| 行 | エージェント | 観点 | 渡す値 |
|---|---|---|---|
| A | `specramo:review-design` | 作業計画書・Phase 詳細設計・Design Doc との比較と、汎用 12 観点 | base、作業計画書と Phase 詳細設計と Design Doc の path、Phase 番号、対象外の作業 |
| B | `specramo:review-history` | チームが過去に受けた指摘の傾向 | base、表示された指摘データの dir |
| C | `specramo:review-rules` | 導入先の repo の規約 | base、表示された規約 file の path (空白区切り) |
| D | `specramo:review-language` | 言語の開発指針 | base、表示された開発指針の file の path (空白区切り。空なら開発指針なし) |

## Step 3: 並列に起動する

`run` の行のエージェントを 1 つの message で並列に起動する。各 prompt に `scope: i/<起動数>` と「commit を順に読む前提の指摘 (commit の往復 / 並び順) は返さない」を記載する。各エージェントは他のエージェントの結果を受け取らずに指摘を返す。

C が「読めなかった file」を返したときは、C の結果を採らず、その旨を表示する。

## Step 4: 統合と出力

- 同じ `file:line` の指摘は 1 件にまとめ、どのエージェントが出したかを添える。重大度が一致しないときは高い方を採る
- 2 つ以上のエージェントが同じ箇所を挙げた指摘は、全員が Info でも Warning に上げる。別々の観点の reviewer が同じ箇所で引っかかったなら、人の reviewer も同じ箇所で問い返すため。「動作は正しい」「別の issue で扱う」は Info に留める理由にしない
- commit を順に読む前提の指摘 (commit の往復 / 並び順) は捨てる。reviewer は全 commit をまとめた PR の diff を読む
- 保存データの構造変更への指摘は、`/specramo:implement` Step 3 と同じ使い捨ての環境で、指摘した箇所と修正案の両方を実行して確かめてから出力する。実行できなかったときは、指摘と修正案に「未検証」と添える。修正案も実行するまで正しいか分からず、確かめない修正案は別のエラーになりうる
- test の結果を確かめるときは次の順で行う
  1. `/specramo:implement` の完了報告の「検証」行にある command と環境変数で、エージェントでなくこの skill を実行している側が 1 回実行する。保存データの構造変更の確認も同じく、この skill を実行している側が行う
  2. その行が無いか、同じ条件で実行できなかったときは「未検証」と添える
  - エージェントに任せない理由: 起動した全エージェントが同じ test を並列に実行するうえ、Bash の許可が下りない環境では誰も実行しないまま終わる
- 出力の冒頭に次の 3 行を置き、`${CLAUDE_PLUGIN_ROOT}/skills/review/perspectives.md` の出力の形で Critical と Warning を並べる

```
review: Phase <n> / 全 <N> — <Phase 名>
base: <ref> (<理由>)
起動: A, C, D (B は省いた: <理由>)
```

- 同じ内容を、作業計画書と同じ dir の `review-phase<n>.md` に書き出す。既にあれば上書きし、最新の review の結果だけを置く (`--fix` の後の再 review も上書きする)。`/specramo:explain` はこの file を読み、未解決の指摘がある箇所を正しい前提として説明しない

## Step 5: 状態を進める

Critical と Warning の合計で、作業計画書の「Phase の状態」の表を書き換える。

- 合計が 0 なら「レビュー済み」にする
- 1 以上なら「実装中」にする

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/phase-state.sh" set <作業計画書の path> <n> レビュー済み
bash "${CLAUDE_PLUGIN_ROOT}/scripts/phase-state.sh" set <作業計画書の path> <n> 実装中
```

終了コードが 3 (遷移に無い) なら、状態を変えずにその表示を利用者に示す。

## Step 6: 修正 (`--fix` のときだけ)

- 修正してよいのは Phase の対象 file と、その test だけにする。対象外の file を変更する修正は行わず報告する
- 修正後は Step 2 から改めて review し、Step 5 で状態を進める
- 指摘の原因が作業計画書 / Phase 詳細設計 / Design Doc の側にあると判断したものは修正せず、`/specramo:phase-design` か `/specramo:design --update` へ戻す。どちらが正かは利用者が決める

## Next の判定

| 状態 | Next |
|---|---|
| Critical / Warning が 0 件 | PR を draft で作成する。その後 `/specramo:explain <機能名> --phase <n>` で説明と自分の認識を突き合わせ、合ったら draft を解除してレビューを依頼する |
| Critical / Warning がある | `/specramo:review <機能名> --phase <n> --fix` |
| 作業計画書 / Design Doc 側の誤りが疑われる | `/specramo:phase-design` か `/specramo:design --update` |

## 失敗時の分岐

| 症状 | 見分け方 | 対処 |
|---|---|---|
| base が決まらない | `git merge-base` が error になるか、前 Phase の branch が手元に無い | `git fetch` 後に改めて実行し、それでも無ければ default branch を base にして理由を `base:` 行に記載する |
| エージェントが結果を返さない | 指摘の一覧も「指摘なし」も返らずに終わる | そのエージェントだけを同じ prompt で 1 回起動し、2 回目も同じなら `起動:` 行にその観点と「未実施」を記載する |
| 指摘の `file:line` が差分に無い | 指摘の行が Step 1 の差分の範囲外 | 差分外の指摘として Critical と Warning の合計に数えず、参考として別に並べる |
| `review-phase<n>.md` を書き出せない | 作業計画書の dir に書き込めない | chat の出力だけで閉じ、書き出せなかった旨と path を 1 行記載する。Step 5 の状態の更新は chat の結果で行う |

## 完了報告の例

```
Phase 2 / 全 4 の review が終わりました。Critical 0 件、Warning 2 件です (A と D が同じ箇所を指摘しています)。結果は review-phase2.md に保存しました。次は `/specramo:review <機能名> --phase 2 --fix` です。
```

## 禁止事項

- `--fix` 以外では code を編集しない
- 作業計画書は「Phase の状態」の表を `phase-state.sh` で更新するだけにし、本文と Phase 詳細設計と Design Doc は編集しない
- 次の Phase へ自動で進まない

## Related

- `/specramo:implement` — この skill の入力を作る。Step 3.5 の点検表をエージェント A が使う
- `/specramo:explain` — review 後の差分説明
