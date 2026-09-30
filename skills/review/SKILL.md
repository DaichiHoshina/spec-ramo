---
description: /specramo:implement で実装した Phase 1 つの差分を、設計書との比較・過去の指摘・repo の規約・言語の開発指針の観点で並列に review し、結果で Phase の状態を進める。「Phase をレビューして」で使う。
argument-hint: "[機能名] [--phase <n>] [--fix]"
disable-model-invocation: true
---

# /specramo:review - Phase の差分を review する

> **Goal**: `/specramo:implement` が実装した Phase n の差分を観点ごとに別のエージェントで review し、利用者が `/specramo:explain` で差分を理解する前に、修正するものを確定させる。結果の Critical と Warning の合計で Phase の状態を進める。

**Position**: `/specramo:implement` (Phase の実装) の後にこの skill を適用する。修正するものが無くなったら `/specramo:explain` (code の説明) から PR へ進む。

## Step 0: 前提確認

次の command を実行する。終了コードが 2 なら、表示をそのまま利用者に示して止まる。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/require-config.sh"
```

作業計画書は、設定 file の `specs_dir` の下の機能名の dir の `plan.md` にある。

## Step 1: 入力

1. 作業計画書を Read する。`--phase` 省略時は、現在の branch 名を作業計画書の各 PR の `branch:` 行と照合して Phase を特定し、Phase 名を 1 行宣言する。一致が無ければ「Phase の状態」の表で「実装中」の最初の行を採用する。
2. Phase の 対象 / 対象外 / 実装への指針 を読む。作業計画書冒頭の `- Design Doc:` 行に path があれば、その Design Doc の受け入れ条件の表も読む。同じ dir に Phase 詳細設計 `plan-phase<n>.md` があれば、`### 変更対象 file` と契約の節を読む (冒頭に「無効」とあるものは使わない)。
3. 作業計画書が Phase を複数の PR に分ける条件を定めているときは、review の範囲を分割後の PR に合わせる。後ろの PR へ回った作業は「対象外 (後続 PR で対応)」として全エージェントの prompt に渡す。
4. 差分の base を決める。作業計画書の `依存:` にある前 Phase の branch が未 merge ならその branch、merge 済みか依存なしなら default branch とし、`git merge-base` の結果を 1 行記載する。差分が空なら「review 対象なし」で終える。

## Step 2: 起動するエージェントを決める

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/select-review-agents.sh" . $(git diff --name-only <base>...HEAD)
```

2 番目以降の引数は差分の file 名で、D に渡す開発指針を拡張子で決める (`.go` なら Go の 5 本、`.ts` / `.tsx` なら TypeScript の 1 本)。表示は 1 行 1 エージェントの tab 区切りで、`run` か `skip` と、渡す値か省いた理由が並ぶ。`warn` の行は C の規約の path が存在しない警告になる。

- `skip` の行の理由と `warn` の行は、そのまま利用者に表示する
- 起動するのは `run` の行のエージェントだけにする。この表示と異なる判断で起動したり省いたりしない

| 行 | エージェント | 観点 | 渡す値 |
|---|---|---|---|
| A | `specramo:review-design` | 作業計画書・Phase 詳細設計・Design Doc との比較と、汎用 12 観点 | base、作業計画書と Phase 詳細設計と Design Doc の path、Phase 番号、対象外の作業 |
| B | `specramo:review-history` | チームが過去に受けた指摘の傾向 | base、表示された指摘データの dir |
| C | `specramo:review-rules` | 導入先の repo の規約 | base、表示された規約 file の path (空白区切り) |
| D | `specramo:review-language` | 言語の開発指針 | base、表示された開発指針の file の path (空白区切り。空なら開発指針なし) |

## Step 3: 並列に起動する

`run` の行のエージェントを 1 つの message で並列に起動する。各 prompt に `scope: i/<起動数>` を記載する。各エージェントは他のエージェントの結果を受け取らずに指摘を返す。

C が「読めなかった file」を返したときは、C の結果を採らず、その旨を表示する。

## Step 4: 統合と出力

- 同じ `file:line` の指摘は 1 件にまとめ、どのエージェントが出したかを添える。重大度が一致しないときは高い方を採る
- 保存データの構造変更への指摘は、`/specramo:implement` Step 3 と同じ使い捨ての環境で、指摘した箇所と修正案の両方を実行して確かめてから出力する。実行できなかったときは、指摘と修正案に「未検証」と添える。修正案も実行するまで正しいか分からず、確かめない修正案は別のエラーになりうる
- test の結果を確かめるときは、`/specramo:implement` の完了報告の「検証」行にある command と環境変数で実行する。その行が無いか、同じ条件で実行できなかったときは「未検証」と添える
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
| Critical / Warning が 0 件 | `/specramo:explain <機能名> --phase <n>` (差分を理解してから PR へ) |
| Critical / Warning がある | `/specramo:review <機能名> --phase <n> --fix` |
| 作業計画書 / Design Doc 側の誤りが疑われる | `/specramo:phase-design` か `/specramo:design --update` |

## 禁止事項

- `--fix` 以外では code を編集しない
- 作業計画書は「Phase の状態」の表を `phase-state.sh` で更新するだけにし、本文と Phase 詳細設計と Design Doc は編集しない
- 次の Phase へ自動で進まない

## Related

- `/specramo:implement` — この skill の入力を作る。Step 3.5 の点検表をエージェント A が使う
- `/specramo:explain` — review 後の差分説明
