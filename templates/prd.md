# PRD の雛形

`/specramo:prd` が使う雛形。導入先の `.specramo/templates/prd.md` に同じ名前の file を置くと、この雛形の代わりに使われる。

```markdown
# PRD: [機能名]

## 1. Overview (目的 / 背景 / 範囲)

## 1.5 判断の根拠 (Q1〜Q5: 本当の目的 / 作らない場合との比較 / 代替案 3 つ / 失敗の想定 3 つ / 前提が崩れる条件)

## 1.6 Non-Goals (今回作らないものを 1 行ずつ、理由を添えて並べる。Q2 と 1. の範囲で対象外にしたものをここに集約し、他の節では参照だけにする)

## 2. Users (対象 / ユーザーストーリー / 役割)

## 3. System (依存するサービス / データの流れ / 外部 API)

## 4. Functional Req (状態遷移 / 業務ルール)

## 4.5 Formalization (複雑な要件のときだけ)

## 5. Non-functional Req

## 6. Acceptance Criteria (条件に AC-1 のような ID を振らない。「〜のとき、〜が〜になる」の判定できる文にし、後続のステップからは条件の文を装飾せずに引用して指す)

## 7. Review Result

## 8. Next Steps
```
