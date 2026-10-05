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

各 Step の細則は `${CLAUDE_PLUGIN_ROOT}/skills/implement/anatomy.md` に置いている。本文で「anatomy」と書いた箇所は、その file の同名の節を読む。

1. 作業計画書を Read する。`--phase` 省略時は「Phase の状態」の表で状態が「未着手」か「実装中」の最初の行を採用する。
2. 着手前に現在地を 4 行で宣言する。この 4 行は着手時と Step 4 の完了報告の 2 回だけ記載する。N の求め方と前後が無いときの書き方は anatomy 「2. 現在地の 4 行」。

   ```
   Phase 2 / 4
   前: Phase 1 保存先の追加
   NOW: Phase 2 登録の処理
   次: Phase 3 参照の処理
   ```

3. 状態を「実装中」にする。終了コードが 3 か 2 なら実装せずに止まる。それぞれの扱いは anatomy 「3. 状態の更新の終了コード」。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/phase-state.sh" set <作業計画書の path> <n> 実装中
   ```

4. Phase 詳細設計 (`/specramo:phase-design` が作成した `plan-phase<n>.md`) を作業計画書と同じ dir で探す。扱いの理由は anatomy 「4. Phase 詳細設計の扱い」。
   - あれば Read して実装形 (公開する型と操作 / 契約 / 問い合わせの方針 / TX / テスト観点 / 変更対象 file) をそのまま採用する。冒頭に「無効」と記載された file は、無いときと同じに扱う
   - 無いときは `/specramo:phase-design` Step 0 の省略判定をこの Phase に当てる。当たるなら作業計画書の 対象 / 完了条件 から実装形を自分で決めてよい
   - **当たらないなら実装へ進まず**、`/specramo:phase-design` を実行するよう 1 行報告して止まる
   - Phase 詳細設計と実物が一致しなかったら実装を進めず、不一致を 1 行報告して `/specramo:phase-design` へ戻す
5. Phase の「実装への指針」に列挙された repo 規範 (rule file) を着手前に Read し、命名 / 型 / 層 / error / test の制約を採用する。
   - 列挙が無いときの rule の選び方 (上限 3 file) と、Phase 詳細設計に無い名前の付け方は anatomy 「5. repo 規範と命名」
6. Phase の 対象 / 対象外 / 完了条件 を scope として採用する。対象外に列挙された file には触らず、変更する必要が発生したら止まって報告する。
7. branch は作業計画書の PR 見出しの `branch:` の名前にし、repo の default branch から作る。同名の branch が既にあれば、そこへ checkout する。
8. 着手前に Phase の「merge 後にできること」と完了条件を 3 行で chat に写し、利用者が読んで理解している前提を作る。AI の出力は下書きで、レビューに提出するのは利用者が説明できる code だけとする。

## Step 2: 実装

- 1 Phase を 1 つの会話で実装する。Phase をさらに別の作業へ分割しない。
- 計画書のタスクが Phase の scope を超えると分かったら、そのタスクは実装せず「別 Phase へ送る」と報告に記載する。作業計画書は `/specramo:plan --update` で更新し、この skill は作業計画書の本文を編集しない。典型は anatomy 「scope を超えるタスク」。
- 計画書と実物の不一致を見つけたら、1 行で報告して再分析に戻る。対象に列挙された file が実物に無いときは不一致でなく新規作成として進め、作成する旨を 1 行で宣言する。何が不一致に当たるかは anatomy 「計画書と実物の不一致」。
- 削除やデータの移行や強制 push を含む Phase は、計画書があっても実行前に確認する。ただし手元の隔離環境に適用するだけなら確認は不要で、共有環境を使わない手順を採る。
- 実装中に既存挙動を変える判断が必要になったら、その場で決めずに `/specramo:design --update` で Design Doc へ記載してから続ける。
- 設計や repo 規範の解釈に迷ったら、その部分を実装せずに止まる。確かめた内容 / 自分の案 / 迷っている点を 3 行で報告し、利用者が進め方を決めてから続ける。
- 上の 2 つに当たる場面は anatomy 「既存挙動を変える判断と、迷ったときに止まる場面」。

## Step 3: 完了条件の実行

- Phase の完了条件に記載された command (test 名 / lint / API response) を改めて実行し、出力と照合する。実行しなかった条件は「未実行」と記載する。
- 完了条件の command は前面で実行し、バックグラウンドで実行しない。長い command も timeout を延ばして結果を待つ (理由は anatomy 「前面で実行する理由」)。
- lint は変更した構成単位 (package / module) か file だけを対象に実行し、対象にした範囲を完了報告の「検証」行に記載する (理由は anatomy 「lint の範囲を限定する理由」)。
- test に必要な環境変数と test の実行条件 (tag 等) は、完了報告の「検証」行に command と一緒に記載する。`/specramo:review` はこの行の command で test を再実行する。
- migration を含む Phase で、共有の DB に適用できないときは、使い捨ての DB を用意して up と down を実行して確かめ、終わったら削除する。用意できない環境では「未実行」と記載する。DB の選び方は anatomy 「migration を含む Phase の使い捨ての DB」。
- 変更した symbol 名と file 名で test の dir を grep し、該当した test file を全部実行する。共有 fixture を変えたときは、同じ fixture dir を読む package の test も全部実行する。
- mutation check として、Phase 詳細設計の「テスト観点」が指す条件を 1 つ壊し、該当の test が fail することを確かめてから元に戻す。
  - 復元は、壊す前の file をコピーしておくか逆置換で行う
  - `git checkout -- <file>` は commit 済みの file にだけ使う (理由は anatomy 「mutation check の復元」)
- 既存 test の FAIL が並列干渉 (単独実行で PASS) なら、test 名と単独実行の結果を報告に記載して無関係と判定する。その場合は「全部 PASS」とは記載しない。

## Step 3.5: self-review (完了報告の前)

diff は reviewer が 1 本で採否を決められる状態にする。Phase の目的の達成に不要な変更を同じ diff に含めない。symbol の rename、format のそろえ直し、周辺 code の書き換えの 3 つが典型になる。含まれていたら別 commit へ分け、分けられないものは PR 本文に理由を 1 行記載する。

`/specramo:review` もこの表を追加の観点として使う。

| # | 点検項目 | 判定基準 |
|---|---|---|
| a | 参照 0 件の symbol の先出し | production の参照が 0 件の symbol を先出ししていない (使う Phase の PR へ送るか、PR 本文に使う Phase を記載する) |
| b | magic number の出所 | 外部仕様の値 (error code / status 等) の出所が comment か定数で分かる (隣接 file の記述に合わせる) |
| c | validation と保存の対称性 | validation で分岐した条件と保存の条件が対称になっている (validation が特定の条件のときだけ見る値を、保存側が無条件に記載していない。Design Doc が「〜なら空」と決めた値は保存側で保証する) |
| d | Non-Goals の制約 | Non-Goals で受け入れた制約が code の該当箇所に 1 行 comment で記載されている |
| e | 値の条件と代入の対応 | Design Doc が決めた各項目の値の条件 (「不要なら空」「未指定なら決まった値」「前の値を引き継ぐ」等) と保存処理の代入が項目ごとに対応している |
| f | 同種箇所の処理し忘れ | repo 規範を適用して 1 箇所を変えたときは、同じ理由で変更が必要な箇所を全部 grep して抜けが無い。同じ型の同種 field、同じ層で同じ役割の別の処理、同じ判定の別の呼び出し元が当たる |
| g | test double の引数照合 | 追加・変更した test double の期待で、値が決まる引数を任意一致 (any matcher など) で受けていない。期待する値を組み立てて照合する |

## Step 4: 完了報告と handoff

完了報告は次の形で閉じる。`<N>` と前後の Phase 名は、作業計画書の「Phase の状態」の表の行から取る (記憶や推定で数えない)。

```
Phase <n> / 全 <N> — <Phase 名>: 完了 / 一部完了 (未達: ...)
現在地: 前 <前の Phase 名 または なし> / 次 <次の Phase 名 または なし>
満たした条件: <条件の文の引用> / 未達: <同>   (計画書が担当条件を記載しているときだけ)
検証: <実行した command と結果 1 行>
mutation check: <壊した条件> → <fail した test 名> / 未実施 (<理由>)   (Phase 詳細設計が対象を決めているときだけ)
Next: /specramo:review <機能名> --phase <n>
```

- 状態は「実装中」のままにし、review の結果で `/specramo:review` が進める。
- この skill は次の Phase に自動で進まない。
- 完了報告の直後に、PR を作成する前の checkpoint を利用者向けに列挙する。確認するのは利用者で、AI は代行しない。
  - test 抜きの変更行数が設定 file の `max_lines` 以下
  - AI が記載した comment が 0 件 (全部書き換えたか削除した)
  - 差分を repo の規約と照らし合わせた (処理を置く場所と層の依存の向き)
  - 参考にした既存実装を 1 つ以上 PR 本文に記載する
  - `/specramo:explain` の説明と自分の理解が一致しなかった箇所が 0 件 (不一致は PR 前に解消する)
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
