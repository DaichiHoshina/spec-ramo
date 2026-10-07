# /specramo:plan Step 2 の scope 走査 checklist

`/specramo:plan` Step 2 で Design Doc に記載された API / Query / Command / 画面ごとに実物を確かめる作業の checklist。本文は「code 解析 tool か grep で対象 file と test file を列挙する」までに限定し、個々の判定はここに記載する。

## 参照件数と Phase 配置

- 既存 field の型変更や nullable 化のタスクは参照件数 (`grep -rl` の file 数) を数え、10 file を超えるものは読み出し Phase でなく書き込み側の Phase か独立 Phase に置く
- 共有 fixture を変更する Phase は、同じ fixture dir を読む package の test を完了条件に含める

## Data Schema の不変条件

- Data Schema の説明列に記載された不変条件 (「サイズ不要なら NULL」「必要 → 不要は拒否」等) は、その列を扱う Phase の完了条件に test 名で転記する
- validation と保存の非対称は test が無いと残存する

## 新規 entity の登録経路

- 新しい保存先へ書き込む Phase は、永続化層で保存先を登録する file を対象に含める
- 登録の file は、repo の登録経路を 1 度だけ grep で確かめて特定する

## 生成物 (swagger 等) の差分

- swagger や生成物の差分を完了条件に含めるときは、その endpoint に annotation があるかを先に確かめる
- annotation の無い endpoint では生成 command の差分が発生しない
- 生成 command の名前は、repo の Makefile や package.json の script から確かめる

## test file の実在確認

- test file は `ls` / Glob で実在を確かめる
- 無い層 (handler test が無い adapter 等) は完了条件に記載せず、代わりに使う test の層を記載するか「新規作成」と明記する

## 画面の repo 特定

- 画面は BE repo に無いことが多いので、Design Doc の Frontend 表の画面ごとに repo を特定する (1 つ上の dir を `ls` して候補を挙げ、画面名で grep して file を特定する)
- 同じ画面が API (JSON) と HTML template の 2 経路で作られている (admin の adminapi と adminweb 等) ときは経路ごとに Phase を分け、画面の表の 1 行を Phase 2 つに割る
- repo が特定できない画面は【未確認】で先送りせず、候補 repo と「見つからなかった grep 語」を記載する
- 画面の Phase の完了条件は、その repo の test の書き方 (file 名の規約、実行 command) を 1 つ参照して test 名で記載し、「手動で確認する」だけで終えない

## Design Doc と code の不一致

Design Doc の記述と code が一致しない点は、次の 2 つに分けて扱う。どちらでも Design Doc 側を明記せずに読み替えない。

- **DD へ戻す**: Design Doc の記述そのものが実物と違う (endpoint の形や存在、条件どうしの矛盾)、または Implementation Surface に行が足りない (決定にある flag や endpoint が表に無い、同じ商品一覧を返す別 endpoint がある)。表の不足は「Design Doc との差分」で進めない
  - 判定表: endpoint / field / flag / table / 画面の不足や形の違い = DD へ戻す
- **差分表に保持して進む**: 同じ結果に至る実装経路が複数ある、処理をどの method に置くか、戻し処理が 2 か所にある。Design Doc の粒度では記載しない実装経路の詳細 (どの関数に置くか、経路が 2 つある) は「Design Doc との差分」に記載して進む

## 作られなくなる状態を読む側

対象は、不変条件を追加する PR、登録経路を 1 本にする PR、旧経路を撤去する PR の 3 種類だけにする。参照条件を変えるだけの PR には課さない。

- PR ごとに「この PR の merge 後、作られなくなる状態」を 1 文で書く (例: 下書きのレコードに、確定の処理でしか設定しない値が付いた状態)
- その状態を読む側を、次の 2 段で grep し、1 行ずつ列挙する。書き込み側 (登録や後始末の分岐) だけを棚卸しすると、表示の分岐や、その状態を fixture で作る test が、どの PR にも含まれない
  1. repo の中: code の分岐 / test / fixture
  2. repo の外へ値を渡す境界: API の応答の項目、enum の値、event や message の項目、export する file の列など、その状態から作る値を外へ渡す箇所。境界ごとに、値を受け取る側 (別 repo の画面や client、他の service) を決めて grep する
- 受け取る側の探し方は、境界の種類で変える

  | 境界 | 受け取る側の探し方 |
  |---|---|
  | 画面向けの API (REST / GraphQL) | 「画面の repo 特定」と同じ方法で画面の repo を決める。BFF や API gateway が間にあれば、そこで項目を詰め替えていないかも確かめる |
  | service 間の API (gRPC / 内部 REST) | IDL (proto 等) の定義 repo で message 名を検索し、その message を import している service を列挙する |
  | event / message (queue / topic / stream) | topic を購読している consumer を、consumer の設定 (subscription / consumer group) と schema registry から列挙する |
  | DB の共有 (別 service の直接参照 / CDC / 分析基盤への連携) | table と列の名前で、他 service の repo と、連携先の定義 (CDC の設定、分析基盤の query) を検索する |

  - 複数の repo を横断して検索できるなら使う (`gh search code --owner <org> '<項目名>'` 等)。手元に clone の無い repo も対象に含めるため
  - 受け取る側を列挙しきれない境界 (外部公開の API、consumer の一覧が無い topic) は、【未確認】として、探した場所と検索した語を記載する。未確認の項目は削除しない側に割り当てる
- 受け取る側の grep は、項目名で止めずに、値を受け取った変数や共通の部品まで追う。項目名が画面固有の dir に無くても、共通の部品が表示していることがある
- 自動生成の型や client にだけ項目名がある場合は、それを参照する画面の code があるかまで確かめる。生成物だけの一致は読む側に数えない
- 列挙した行の割り当ては `phase-anatomy.md` 「作られなくなる状態の読み手と PR の割り当て」に従う。境界の項目も同じ表で割り当て、削除するかどうかを計画の時点で決める。`/specramo:phase-design` は、削除すると決めた項目について API 仕様と生成物の変更方法だけを扱う
