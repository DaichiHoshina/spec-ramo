# PR が 3 本以上のときの依存の書き方

`/specramo:plan` が、Phase が 3 つ以上の作業計画書でマージ順序と依存関係を記載するときの規則。PR を 1 本ずつ前の PR の上に重ねて進める (stacked PR chain) ことを前提にする。

## マージ順序と依存の記載

- 作業計画書の「マージ順序と依存関係」の節に、PR の依存の向きを図で示す。枝分かれと再結合がある場合だけ図が役に立つので、一本道なら番号付きの箇条書きでもよい
- 各 PR の直下の「依存:」に、先に merge が必要な PR の番号を記載する
- 並行して進めてよい PR (互いに依存しない PR) は、その旨を 1 行で記載する

## 未使用の引数を先に追加しない (YAGNI)

「他の usecase の constructor が 2 引数だから合わせる」のような慣習合わせで、その PR で使わない引数を signature に追加しない。使う PR で追加する方が、後続の PR の更新作業が減る。

- 未使用の引数は、後続の PR に呼び出し側の signature の変更を要求する
- 後から本当に必要になったとき、既存の引数と別名で追加するか統合するかの判断が必要になる
- signature の変更は「その PR 内で使う分だけ」にとどめる

## 後続の PR に送る symbol

上流の PR で「後続の PR で定義する」と決めた symbol (error の定数 / rename / helper) が、後続の PR に反映されないまま最後の PR で未定義になる事故がある。PR 単体の diff レビューでは検知できない。

- 上流の PR の本文に「後続の PR 用に先出しする symbol」の節を置き、symbol 名と想定する置き場所を明記する
- 上流の PR を merge したら、後続の PR の base branch を実際に checkout して build が成功することを確かめる
- 最後の PR では、全部の PR を重ねた状態で build と静的検査を成功させる
- rename をした後に追加した新しい code にも、旧名が無いかを grep で確かめる

## 責務の契約を分割前に決める

writer 層 / usecase 層 / adapter 層のどこが error の変換を担うかを、PR を分ける前に決める。決めないまま分けると、「writer 側の実装は後続の PR、usecase 側は変換後の error を参照済み」のような不一致で build が失敗する。

## 途中の PR を統合するとき

- 途中の PR を統合するときは、close して内容を別の PR へ手でコピーせず、base branch に対象の branch を merge commit で取り込む。統合の事実が commit と PR の両方に記録される
- 上流の PR の変更は、上流から順に後続の branch へ merge で伝える。rebase は force push が必要で、レビュー済みの PR の commit と inline comment の位置が変わるので使わない
