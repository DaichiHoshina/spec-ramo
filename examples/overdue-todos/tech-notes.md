# 技術メモ: 期限切れ TODO の一覧 (overdue-todos)

[PRD](./prd.md) に記載しない技術的な内容をまとめる。code の位置は、この技術メモを作成した時点の事実である。`/specramo:design` は実物で確かめてから使う。

## 現在の code

- `todo/handler.go:11`: `GET /todos` は全件を JSON で返すだけで、条件で抽出する処理が無い
- `todo/todo.go:6`: `Todo.Due` の zero value を「期限なし」として扱う。PRD の **期限なし** はこの値に当たる
- `todo/store.go:6`: `Store` は `sync.Mutex` で `Add` と `List` を保護している
- `todo/store.go:23`: `Store.List` は全件を新しい slice に複製して返す
- `go.mod`: 外部 library の require が 0 件で、標準 library だけで実装できる
- repo 内で API を呼んでいるのは test (`todo/handler_test.go`) だけで、外部の client の数は確かめていない

## 処理の流れ (案)

1. client が `GET /todos/overdue` を呼ぶ
2. handler が現在時刻を確定する
3. handler が `Store` から期限切れの TODO を取得する。`Store` は lock の中で slice を走査し、条件に当てはまる TODO だけを集める
4. handler が結果を期限の古い順に並べ、JSON の配列として返す

## 実装で注意する点

- **抽出処理の置き場所**: handler で `Store.List` を呼んでから抽出すると、返す件数と無関係に全件の複製が発生する。抽出は `Store` 側の関数に置き、lock の中で判定する
- **現在時刻の受け渡し**: 関数の内部で現在時刻を取得すると、期限ちょうどの境界を test で固定できない。時刻を引数で受け取る形を推奨する
- **0 件の応答**: Go の nil slice をそのまま JSON にすると `null` になる。空の slice を返し、`[]` にする
- **比較**: `time.Time` の比較は絶対時刻で行われるので、`Due` に付いた timezone の表記に判定が依存しない

## 前提が成り立たなくなったときの費用 (概算)

- 保存先がメモリから DB に変わる: 抽出の関数 1 つを問い合わせに書き換え、index を検討する。関数の呼び出し側は変更せずに済む
- 認証を追加し、利用者ごとの TODO になる: 関数に利用者の引数を追加し、handler で利用者を特定する
- 期限の意味が日付単位に変わる: 判定条件を書き換え、timezone の方針を決める
