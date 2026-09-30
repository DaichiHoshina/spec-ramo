# サンプル: 期限切れの TODO の一覧

小さな TODO の HTTP API (Go、メモリに保存) に、`GET /todos/overdue` で期限切れの TODO を一覧する機能を追加する題材です。この dir の file は、Spec Ramo のコマンドを実際に実行して作った成果物です。ただし PRD と技術メモは、PRD の雛形を改めたときに、内容を変えずに新しい節の構成へ手で書き直しました。

| file | 作ったコマンド | 内容 |
|---|---|---|
| [prd.md](prd.md) | `/specramo:prd` | 要求。期限なしと完了済みを含めないこと、判定は現在時刻と比べること |
| [tech-notes.md](tech-notes.md) | `/specramo:prd` | PRD に記載しない技術メモ。現在の code の位置と、実装で注意する点 |
| [design.md](design.md) | `/specramo:design` | 受け入れ条件の表で振る舞いを固定した Design Doc |
| [plan.md](plan.md) | `/specramo:plan` | 2 つの Phase (期限切れの判定 / 一覧の endpoint) に分けた作業計画書 |
| [plan-phase1.md](plan-phase1.md) | `/specramo:phase-design` | Phase 1 の実装方法 |

Phase 2 は判断の分岐が無いので、Phase 詳細設計を省く判定になります。

## 自分の repo で同じ流れを試す

1. 次の 3 file だけの Go の repo を用意する (`go.mod` の module は任意)
   - `todo/todo.go`: `Todo` 型 (`ID` / `Title` / `Due time.Time` / `Done`)
   - `todo/store.go`: 排他制御つきのメモリの保存 (`Add` / `List`)
   - `todo/handler.go`: `GET /todos` で全件を JSON で返す handler
2. GitHub に push し、Claude Code で Spec Ramo を導入して `/specramo:init` を実行する
3. 次のコマンドを順に実行する

   ```text
   /specramo:prd overdue-todos 期限を過ぎても完了していない TODO を GET /todos/overdue で一覧したい
   /specramo:design overdue-todos
   /specramo:plan overdue-todos --phases 2
   /specramo:phase-design overdue-todos --phase 1
   /specramo:explain overdue-todos --phase 1
   /specramo:implement overdue-todos --phase 1
   /specramo:review overdue-todos --phase 1
   /specramo:explain overdue-todos --phase 1
   ```

4. 差分を理解できたら、作業計画書の PR #1 の branch で PR を作る
5. Phase 2 も `/specramo:explain` から同じ順に進める (`/specramo:phase-design` は省く)
6. `/specramo:status` で、PR を作った Phase が「PR 作成済み」になったことを確かめる

生成される文章はこの dir の file と同じにはなりません。検査 script (`dd-gate.sh` / `spec-gate.sh`) が FAIL 0 になり、「Phase の状態」の表が PR ごとに 1 行ずつあれば、同じ流れを再現できています。
