---
description: 作業計画書の Phase を 1 つ実装し、完了条件を command で確かめる。「Phase n 実装して」「作業計画書通りに実装」で使う。
argument-hint: "[機能名] [--phase <n>]"
disable-model-invocation: true
---

# /specramo:implement - 作業計画書の Phase を 1 つ実装する

> **Goal**: `/specramo:plan` が作成した作業計画書の Phase n だけを実装し、完了条件を command で確かめ、`/specramo:review` で review を受けられる状態で止める。PR は作らない。

**Position**: 仕様の `/specramo:design`、Phase = PR 分割の `/specramo:plan`、Phase n の実装方法の `/specramo:phase-design`、設計の説明の `/specramo:explain`、Phase の実装のこの skill、Phase の review の `/specramo:review`、code の説明の `/specramo:explain` の順に進む。PR は利用者が作る。

## Step 0: 前提確認

1. 次の command を実行する。終了コードが 2 なら、表示をそのまま利用者に示して止まる。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/require-config.sh"
   ```

2. 作業計画書は、設定 file の `specs_dir` の下の機能名の dir の `plan.md` にある。機能名が引数に無ければ、`specs_dir` の下で最後に更新された `plan.md` を候補にして path を 1 行宣言する。候補が無いときだけ 1 問で機能名を聞く。

## Step 1: 入力

1. 作業計画書を Read する。`--phase` 省略時は「Phase の状態」の表で状態が「未着手」か「実装中」の最初の行を採用する。
2. 着手前に現在地を 4 行で宣言する。N は「Phase の状態」の表の行数にする。前後が無い Phase の行は `前: なし` / `次: なし` とする。この 4 行は着手時と Step 4 の完了報告の 2 回だけ記載する。

   ```
   Phase 2 / 4
   前: Phase 1 Schema
   NOW: Phase 2 Command
   次: Phase 3 Usecase
   ```

3. 状態を「実装中」にする。終了コードが 3 (遷移に無い。たとえば PR 作成済み) なら、実装せずにその表示を利用者に示して止まる。終了コードが 2 なら、作業計画書に「Phase の状態」の表か行が無いので、`/specramo:plan` で表を補うよう 1 行報告して止まる。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/phase-state.sh" set <作業計画書の path> <n> 実装中
   ```

4. Phase 詳細設計 (`/specramo:phase-design` が作成した `plan-phase<n>.md`) を作業計画書と同じ dir で探し、あれば Read して実装形 (interface / method / 契約 / SQL 方針 / TX / テスト観点 / 変更対象 file) をそのまま採用する。
   - 冒頭に「無効」と記載された Phase 詳細設計は、作業計画書を更新した後の古い契約なので、file が無いときと同じに扱う
   - 無いときは `/specramo:phase-design` Step 0 の省略判定をこの Phase に当てる。当たるなら作業計画書の 対象 / 完了条件 から実装形を自分で決めてよい
   - **当たらないなら実装へ進まず**、`/specramo:phase-design` を実行するよう 1 行報告して止まる
   - Phase 詳細設計と実物が食い違ったら実装を進めず、食い違いを 1 行報告して `/specramo:phase-design` へ戻す
5. Phase の「実装への指針」に列挙された repo 規範 (rule file) を着手前に Read し、命名 / 型 / 層 / error / test の制約を採用する。
   - 列挙が無ければ、設定 file の `rules` に並べた file (未記入なら repo の `.claude/rules/` の file) から、この Phase の対象に当たるものを Read する。上限は 3 file にする
   - Phase 詳細設計に無い関数名と変数名は、同梱した `code-quality.md` の「Naming Criteria」の 3 基準と「Naming Shape」で付ける。同じ層の先例を grep して多数派の語を使う
   - 対象言語の開発指針が `${CLAUDE_PLUGIN_ROOT}/guidelines/languages/` にあれば、その「Naming Conventions」も当てる
6. Phase の 対象 / 対象外 / 完了条件 を scope として採用する。対象外に列挙された file には触らず、変更する必要が発生したら止まって報告する。
7. branch は作業計画書の PR 見出しの `branch:` の名前にし、repo の default branch から作る。同名の branch が既にあれば、そこへ checkout する。
8. 着手前に Phase の「merge 後にできること」と完了条件を 3 行で chat に写し、利用者が読んで理解している前提を作る。AI の出力は下書きで、レビューに提出するのは利用者が説明できる code だけとする。

## Step 2: 実装

- 1 Phase を 1 つの会話で実装する。Phase をさらに別の作業へ分割しない。
- 計画書のタスクが Phase の scope を超えると分かったら、そのタスクは実装せず「別 Phase へ送る」と報告に記載する。参照が 10 file を超える rename や nullable 化が典型になる。作業計画書は `/specramo:plan --update` で更新し、この skill は作業計画書の本文を編集しない。
- 計画書と実物の食い違いを見つけたら、1 行で報告して再分析に戻る。symbol 名が違う場合と、対象外や未列挙の file を変更する必要が発生した場合がこれに当たる。対象に列挙された file が実物に無いときは食い違いでなく新規作成として進め、作成する旨を 1 行で宣言する。
- 削除や migration や force を含む Phase は、計画書があっても実行前に確認する。ただし migration を local の DB に当てるだけなら確認は不要で、共有 DB を使わない手順を採る。
- 実装中に既存挙動を変える判断が必要になったら、その場で決めずに `/specramo:design --update` で Design Doc へ記載してから続ける。error 応答の形や、共有 usecase 経由の別入口への制約がこれに当たる。
- 設計や repo 規範の解釈に迷ったら、その部分を実装せずに止まる。迷う場面は、処理の置き場所、層の依存の向き、既存 rule がこの場面に当たるかの 3 つが多い。確かめた内容 / 自分の案 / 迷っている点を 3 行で報告し、利用者が進め方を決めてから続ける。

## Step 3: 完了条件の実行

- Phase の完了条件に記載された command (test 名 / lint / API response) を改めて実行し、出力と照合する。実行しなかった条件は「未実行」と記載する。
- migration を含む Phase で、共有の DB に適用できないときは、使い捨ての DB を用意する。共有の DB に適用できないのは、他の branch の schema が入っているときや、他の作業と共有しているときになる。使い捨ての DB は、手元の DB server に作る別名の database (`specramo_` で始まる名前) か、repo と同じ version の DB を起動した container (`specramo-` で始まる名前) のどちらかにする。そこで up と down を実行して確かめ、終わったら database か container を削除する。どちらも用意できない環境では「未実行」と記載する。migration の構文や ALGORITHM の指定の誤りは、DB で実行するまで分からない。
- 変更した symbol 名と file 名で test の dir を grep し、hit した test file を全部実行する。共有 fixture を変えたときは、同じ fixture dir を読む package の test も全部実行する。
- mutation check として、Phase 詳細設計の「テスト観点」が指す条件を 1 つ壊し、該当の test が fail することを確かめてから元に戻す。
  - 復元は、壊す前の file をコピーしておくか逆置換で行う
  - `git checkout -- <file>` は未 commit の修正まで消すので、commit 済みの file にだけ使う
- 既存 test の FAIL が並列干渉 (単独実行で PASS) なら、test 名と単独実行の結果を報告に記載して無関係と判定する。その場合は「全部 PASS」とは記載しない。

## Step 3.5: self-review (完了報告の前)

diff は reviewer が 1 本で採否を決められる状態にする。Phase の目的の達成に不要な変更を同じ diff に含めない。symbol の rename、format のそろえ直し、周辺 code の書き換えの 3 つが典型になる。含まれていたら別 commit へ分け、分けられないものは PR 本文に理由を 1 行記載する。

`/specramo:review` もこの表を追加の観点として使う。

| # | 点検項目 | 判定基準 |
|---|---|---|
| a | 参照 0 件の symbol の先出し | production の参照が 0 件の symbol を先出ししていない (使う Phase の PR へ送るか、PR 本文に使う Phase を記載する) |
| b | magic number の出所 | DB の error 番号等に出所の comment か定数がある (隣接 file の記述に合わせる) |
| c | validation と保存の対称性 | validation で分岐した条件と保存の条件が対称になっている (Data Schema の「〜なら NULL」は保存側で保証する) |
| d | Non-Goals の制約 | Non-Goals で受け入れた制約が code の該当箇所に 1 行 comment で記載されている |
| e | NULL 条件と代入の対応 | Data Schema の各列の NULL 条件と usecase の代入が列ごとに対応している |
| f | 同種 field の取りこぼし | repo 規範を当てて型を変えたときは、同じ struct 内の同種 field を全部 grep して取りこぼしが無い |

## Step 4: 完了報告と handoff

完了報告は次の形で閉じる。`<N>` と前後の Phase 名は、作業計画書の「Phase の状態」の表の行から取る (記憶や推定で数えない)。

```
Phase <n> / 全 <N> — <Phase 名>: 完了 / 一部完了 (未達: ...)
現在地: 前 <前の Phase 名 または なし> / 次 <次の Phase 名 または なし>
満たした条件: <条件の文の引用> / 未達: <同>   (計画書が担当条件を記載しているときだけ)
検証: <実行した command と結果 1 行>
Next: /specramo:review <機能名> --phase <n>
```

- 状態は「実装中」のままにし、review の結果で `/specramo:review` が進める。
- この skill は次の Phase に自動で進まない。
- 完了報告の直後に、PR を作成する前の checkpoint を利用者向けに列挙する。確認するのは利用者で、AI は代行しない。
  - test 抜きの変更行数が設定 file の `max_lines` 以下
  - AI が記載した comment が 0 件 (全部書き換えたか削除した)
  - 差分を repo の規約と照らし合わせた (処理を置く場所と層の依存の向き)
  - 参考にした既存実装を 1 つ以上 PR 本文に記載する
  - `/specramo:explain` の説明と自分の理解が食い違った箇所が 0 件
  - PR 説明文を自分の言葉で書き換えた。diff の各変更について「なぜ必要か」を一言で言える

## 守ること

- 対象外の file を変更しない。変更する必要が発生したら止まって報告する (計画書の scope が正本)
- 対象 file の内側でも、Phase 詳細設計に記載が無い変更 (comment の書き換え / rename / 周辺の整理) を加えない。実装後に `git diff --stat <base>..HEAD` を取り、Phase 詳細設計の `### 変更対象 file` と件数・file 名を突き合わせる
- 完了条件を command で確かめる前に「完了」と記載しない
- Phase を 2 つ以上まとめて実装しない (1 Phase = 1 PR)
- Phase 詳細設計が見つからない (「無効」と記載された file を含む) まま、省略判定にも当たらない Phase を実装しない
- 作業計画書は「Phase の状態」の表を `phase-state.sh` で更新するだけにし、本文は編集しない

## Related

- `/specramo:plan` — 入力の作業計画書を作成する
- `/specramo:phase-design` — Phase の実装形を決める。この skill の入力になる
- `/specramo:review` — 完了後の Phase の review
- `/specramo:explain` — review 後の差分説明
