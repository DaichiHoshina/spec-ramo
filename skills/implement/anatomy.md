# /specramo:implement の細則 (Step 1 / 2 / 3 の判定方法)

`skills/implement/SKILL.md` の各 Step から読む。規則の中身は SKILL.md と同じで、SKILL.md には手順の骨格だけを置いている。

## Step 1: 入力の細則

### 2. 現在地の 4 行

- N は「Phase の状態」の表の行数にする
- 前後が無い Phase の行は `前: なし` / `次: なし` とする
- この 4 行は着手時と Step 4 の完了報告の 2 回だけ記載する

### 3. 状態の更新の終了コード

- 終了コードが 3 (遷移に無い。たとえば PR 作成済み) なら、実装せずにその表示を利用者に示して止まる
- 終了コードが 2 なら、作業計画書に「Phase の状態」の表か行が無いので、`/specramo:plan` で表を補うよう 1 行報告して止まる

### 4. Phase 詳細設計の扱い

- **「無効」と記載された file**: 冒頭に「無効」と記載された Phase 詳細設計は、作業計画書を更新した後の古い契約なので、file が無いときと同じに扱う
- **見つからないとき**: `/specramo:phase-design` Step 0 の省略判定をこの Phase に当てる。当たるなら作業計画書の 対象 / 完了条件 から実装形を自分で決めてよい
- **実物と一致しないとき**: 実装を進めず、不一致を 1 行報告して `/specramo:phase-design` へ戻す

### 5. repo 規範と命名

- 「実装への指針」に列挙が無ければ、設定 file の `rules` に並べた file (未記入なら repo の `.claude/rules/` の file) から、この Phase の対象に当たるものを Read する。上限は 3 file にする
- Phase 詳細設計に無い関数名と変数名は、同梱した `code-quality.md` の「Naming Criteria」の 3 基準と「Naming Shape」で付ける。同じ層の先例を grep して多数派の語を使う
- 対象言語の開発指針を `${CLAUDE_PLUGIN_ROOT}/guidelines/languages/extensions.tsv` で変更する file の拡張子から引き、行があればその指針の「Naming Conventions」も当てる。行が無い言語は repo 規範と `code-quality.md` だけで決める

## Step 2: 実装の細則

### scope を超えるタスク

- 参照が 10 file を超える rename や nullable 化が典型になる
- 作業計画書は `/specramo:plan --update` で更新し、この skill は作業計画書の本文を編集しない

### 計画書と実物の不一致

- symbol 名が違う場合と、対象外や未列挙の file を変更する必要が発生した場合がこれに当たる
- 対象に列挙された file が実物に無いときは不一致でなく新規作成として進め、作成する旨を 1 行で宣言する

### 既存挙動を変える判断と、迷ったときに止まる場面

- 既存挙動を変える判断は、error 応答の形や、業務処理の層を共有する別の入口への制約がこれに当たる
- 迷う場面は、処理の置き場所、層の依存の向き、既存 rule がこの場面に当たるかの 3 つが多い

## Step 3: 完了条件の実行の細則

### 前面で実行する理由

バックグラウンドで実行すると、非対話の実行では結果を受け取る前に会話が終わり、完了報告と使い捨ての DB の削除が実行されない。長い command も timeout を延ばして結果を待つ。

### lint の範囲を限定する理由

repo 全体の lint は大きな repo では timeout を超える。対象にした範囲は完了報告の「検証」行に記載する。

### migration を含む Phase の使い捨ての DB

1. 共有の DB に適用できないのは、他の branch の schema が入っているときや、他の作業と共有しているときになる
2. 使い捨ての DB は、手元の DB server に作る別名の database (`specramo_` で始まる名前) か、repo と同じ version の DB を起動した container (`specramo-` で始まる名前) のどちらかにする
3. そこで up と down を実行して確かめ、終わったら database か container を削除する
4. どちらも用意できない環境では「未実行」と記載する

migration の構文や ALGORITHM の指定の誤りは、DB で実行するまで分からない。

### mutation check の復元

- 復元は、壊す前の file をコピーしておくか逆置換で行う
- `git checkout -- <file>` は未 commit の修正まで消すので、commit 済みの file にだけ使う
