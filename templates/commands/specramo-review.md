---
allowed-tools: Read, Glob, Grep, Bash, Task, Skill, Agent, mcp__serena__*
description: /sdd-implement で実装した Phase 1 つの diff に、既存の /review (comprehensive-review) を Phase の scope と作業計画書固有の観点で当てる。/sdd-implement の出口
argument-hint: "<作業計画書 path> [--phase <n>] [--fix] [--panel]"
---

# /sdd-review - Phase の diff を review する

> **Goal**: `/sdd-implement` が実装した Phase n の diff に既存の `/review` を当て、user が `/explain` で差分を理解する前に修正するものを確定させる。汎用の 12 観点と作業計画書・Phase 詳細設計から取った Phase 固有の観点に、guideline 全載せの観点と team の過去の指摘傾向を、別々の agent で並列に加える。

**Position**: `/sdd-implement` (Phase 実装) の次に **`/sdd-review`** を当てる。修正するものが無くなったら `/explain` (code の説明) から PR と次 Phase へ進む

## When to use (棲み分け)

| Command | Use |
|---|---|
| `/sdd-review <path> --phase <n>` | Phase n の diff を、作業計画書の scope と Phase 固有の観点付きで review する (この command) |
| `/review` | 任意の diff の汎用 review。この command が内部で呼ぶ |
| `/review-member` | team の過去の指摘傾向で確認する。この command は毎回、同じ手順を agent B に当てさせる |
| `/review --full` | guideline を全載せしてから review する。この command は毎回、同じ手順を agent C に当てさせる |
| repo の規範 | repo が自前の rule / review 定義を保持するとき、この command は毎回 agent D にそれを当てさせる |

「Phase をレビューして」「作業計画書と突き合わせてレビュー」で発火する。

## Step 1: 入力

1. 引数の path を作業計画書として Read する。無ければ同 session で `/sdd-implement` が最後に扱った path を使い、それも無ければ 1 問で聞く
2. `--phase` 省略時は、現在の branch 名を作業計画書の各 PR の `branch:` 行と照合して Phase を特定する。一致が無ければ `/sdd-implement` が最後に完了報告した Phase を採り、Phase 名を 1 行宣言する
3. Phase の 対象 / 対象外 / 実装への指針 を読む。作業計画書冒頭の `- Design Doc:` 行に path があれば、その Design Doc の受け入れ条件の表も読む (agent A の受け入れ条件 lens が使う)。同じ dir にPhase 詳細設計 `<作業計画書の basename>-phase<n>.md` があれば、「変更対象 file」の見出し (2026-09-25 以降の形式では「実装メモ」の下、それ以前は本文の節) と契約の節を読む (冒頭に「無効」とあるものは使わない)
4. 作業計画書が Phase を複数の PR に分ける条件を定めているとき (「400 行を超える見込みなら、登録の移動を PR #4 に分ける」等) は、review の範囲を分割後の PR に合わせる
   - 現在の branch がどちらの PR に当たるかを、branch 名と diff の中身で判定して 1 行記載する
   - その PR が担当する作業だけを review の対象にする。後ろの PR へ回った作業は「対象外 (後続 PR で対応)」として agent の prompt に渡す
   - 後続 PR の branch があれば、回した作業がそこで実際に扱われているかを grep で確かめて出力に添える
   - この PR だけを先にリリースしたときに起きる問題 (後続 PR で解消する問題) は、重大度を下げずに Critical / Warning のまま出力し、「後続 PR と同時にリリースすれば解消」と書き添える
5. diff の base を決める。作業計画書の `依存:` にある前 Phase の branch が未 merge ならその branch、merge 済みか依存なしなら default branch とし、`git merge-base` の結果を 1 行記載する。diff が空なら「review 対象なし」で終える

## Step 2: review を当てる (3〜4 agent 並列)

既存の review 手順をそのまま使い、この command では独自の rule を定義しない。観点ごとに `reviewer-agent` を分け、単一 message で並列に起動する (A / B / C は常に、D は repo の rule か review 定義があるときに加える。`scope: i/<起動数>` を各 prompt に記載する)。各 agent は他の agent の結果を見ずに指摘を返す。scope はどれも Step 1 の base からの diff に限り、Step 1 の 4 で PR の分割を判定したときは、後続 PR へ回った作業を対象外として全 prompt に渡す。

`reviewer-agent` の tool には Skill が無いので、skill を呼ばせず、手順の file を Read してその手順に従うよう prompt に記載する。

| agent | 観点 | 手順の正本 |
|---|---|---|
| A: 汎用 + Phase 固有 | `comprehensive-review` の 12 観点に、下の追加 lens 5 つを加える | `skills/comprehensive-review/SKILL.md` |
| B: team の指摘傾向 | `review-member` の lens と差分外 routine | `skills/review-member/SKILL.md` |
| C: guideline 全載せ | `/review --full` と同じ guideline を agent 自身が Read し、その観点を指摘の根拠に使う。読んだ file 名を 1 行で報告させる | `references/review-commands.md` 「Full guideline load」 |
| D: repo の規範 | (1) 変更 file に当たる repo の rule 全部と (2) repo 自前の review agent 定義 (定義が参照する skill / checklist を含む) の観点を当てる | (1) `~/.claude/scripts/resolve-repo-rules.sh <変更 file>...` が返す rule。exit 3 なら `<repo>/.claude/rules/*.md` 冒頭の `paths:` と変更 file を突き合わせて抽出する (生成物と正本が別 dir にある repo でも本文は同じなので、読むのはどちらか一方でよい)。(2) `resolve-repo-rules.sh --review-docs` が返す file。exit 3 なら `ls <repo>/.claude/agents/ <repo>/shared-rules/agents/ 2>/dev/null` で名前に review を含む定義を探す。(1) も (2) も無ければ D は起動せず、その旨を 1 行出力する |

agent D の prompt には、親が解決した rule と review 定義の絶対 path を全部記載し、「最初に全 file を Read し、読んだ file 名を報告の冒頭に記載する。Read できなかった file があれば、その旨を返して review をしない」と記載する。定義を読まずに汎用の観点で review した結果は D の結果として採らず、読ませてからもう一度実行させる (2026-09-25 実踏: 定義を読まないまま指摘 0 件で返った)。

agent A に渡す追加 lens:

- **Phase の scope**: 対象外に列挙された file / 振る舞いへの変更 (Critical)、Phase 詳細設計の変更対象 file に無い変更と、Phase の目的に不要な rename / format / 周辺の書き直し (Warning)
- **`/sdd-implement` Step 3.5 の点検表 a-f**: 参照 0 件の symbol の先出し / magic number の出所 / validation と保存の対称性 / Non-Goals の残存 comment / NULL 条件と代入の対応 / 同種 field の取りこぼし
- **Phase の実装への指針**: Phase の「実装への指針」に列挙された rule file (絶対 path)。repo の rule 全体は agent D が担当するので、A はこの列挙分だけを Phase 固有の観点として読む
- **受け入れ条件**: 作業計画書の「目的と実装の対応」表 (無ければ各 Phase の完了条件) で、この Phase が担当する受け入れ条件と、前の Phase が担当した受け入れ条件を取り出し、Design Doc の条件文と diff を突き合わせる。(1) この Phase の担当条件が diff に無い / 一部だけ / 条件文と食い違う (Critical)。(2) 前の Phase の担当条件を、この diff が変えている (Critical)。Design Doc の path が無い作業計画書では、この lens を省いた旨を 1 行出力する
- **命名**: diff で新設した関数名と変数名を `guidelines/common/code-quality-design.md` 「Naming Criteria」の 3 基準と「Naming Shape」、対象言語の `guidelines/languages/<言語>.md` 「Naming Conventions」で点検する (repo に無い語 / 難しい英語 / 削れる語 / 名前の形。Warning)

統合 (親が行う):

- Stage A / B の self-review・repo rule の解決・noise 基準・出力形式は `commands/review.md` の「Delegation & Self-Review」「Review Policy & Scope」「Output Format」に従う
- 各 agent の指摘のうち同じ `file:line` のものは 1 件にまとめ、どの agent が出したかを添える。重大度が食い違うときは高い方を採る
- agent B が「lens data 未設定のため team 傾向の照合を skip した」と返したら、その 1 行を出力に含めて A と C だけで閉じる
- `--panel` のときは agent A を `/review --panel` の lens 構成 (style / security / test-coverage の 3 並列) に置き換える

## Step 3: 出力

`/review` の Output Format で記載し、冒頭に次の 2 行を置く。

```
sdd-review: Phase <n> / 全 <N> — <Phase 名>
base: <ref> (<理由>)
```

末尾に Next を 1 行記載する。

## Step 4: 修正 (`--fix`)

- `/review` の Fix loop をそのまま使う (developer-agent へ委譲し、再 review で回帰を確かめる。停止条件も同じ)
- 修正してよいのは Phase の対象 file と、その test だけとする。対象外の file を変更する修正は行わず報告する
- 指摘の原因が作業計画書 / Phase 詳細設計 / Design Doc の側にあると判断したものは修正せず、`/sdd-phase-design` か `/sdd-design --update` へ戻す。どちらが正かは user が決める

## Next の判定

| 状態 | Next |
|---|---|
| Critical / Warning が 0 件 | `/explain` (Phase の差分を理解してから PR へ) |
| Critical / Warning がある | `/sdd-review <path> --phase <n> --fix` |
| 作業計画書 / Design Doc 側の誤りが疑われる | `/sdd-phase-design` か `/sdd-design --update` |

## 禁止事項

- `--fix` 以外では code を編集しない
- 作業計画書 / Phase 詳細設計 / Design Doc を編集しない。不足は `--update` の経路へ戻す
- 次 Phase へ自動で進まない

## Related

- `commands/sdd-implement.md` — この command の入力を作る。Step 3.5 の点検表を追加 lens として使う
- `commands/review.md` / `skills/comprehensive-review/SKILL.md` — review の手順の正本
- `skills/review-member/SKILL.md` — agent B の手順
- `references/review-commands.md` 「Full guideline load」 — agent C の手順
- `scripts/resolve-repo-rules.sh --review-docs` — agent D が当てる repo の review 定義の解決
- `references/design-phase-flow.md` — 遷移全体
