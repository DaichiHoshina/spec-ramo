#!/usr/bin/env bats
# dd-gate.sh: spec 型 DD の script 判定。良い fixture で PASS し、条件を 1 つ壊すと該当項目だけ FAIL することを見る。

# GNU sed と BSD sed で -i の引数の形が違うので、どちらでも動く形にする
sedi() {
  if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi
}

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PROJECT_ROOT}/scripts/dd-gate.sh"
  DD="${BATS_TEST_TMPDIR}/dd.md"
  cat > "$DD" <<'EOF'
# Design Doc: 例

## 4. Implementation Surface

合計: API 既存拡張 2 本 (Read 1 / Write 1)、新規 Read 1、画面 1、DB 新規 table 1。

### Backend API

| endpoint | 種別 | 変更 | 主な責務 |
| --- | --- | --- | --- |
| `GET /v2/things/:id` | Read | 既存拡張 | 物を返す |
| `PUT /v2/things/:id` | Write | 既存拡張 | 物を更新する |

### Frontend

| 画面 | 種別 | FE 側の logic |
| --- | --- | --- |
| 物の編集 | 更新 | 入力検証がある |

### Data Schema

| table | 変更 | 用途 |
| --- | --- | --- |
| 物 | 新規 | 物を持つ |

## 5. Acceptance Criteria

### 5.1 PRD に書き戻す要件

| # | 条件 | 書き戻し先 |
| --- | --- | --- |
| 1 | 運営が物を更新したとき、名前が空ならサーバは拒否する | PRD の admin 節 |
| 2 | 運営が物を登録したとき、一覧へ並ぶ | PRD の admin 節 |

## 6. 振る舞い

物の更新は名前の検証を経て保存する。

## 7. Design Decisions

| 領域 | 決定 | 却下した案 |
| --- | --- | --- |
| 保存 | 既存 endpoint を拡張する | 新設する |

### 決定 1: 物は別 table に持つ

- 決定: 別 table。
- 却下した案: 列追加。

## 10. Open Questions

| # | 事項 | 暫定決定 | 再レビューの条件 | 確認先 |
| --- | --- | --- | --- | --- |
| Q1 | 確定: 物の単位は 1 件 (2026-09-06) | 決定 1 | — | 運営 |
| Q2 | 名前の上限は何字か | 決定 1 (暫定決定) | 運営が 100 字超を要ると判明 | 運営 (DD レビュー) |
EOF
}

@test "dd-gate: 整合した DD は全項目 PASS で exit 0" {
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^FAIL')" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  surface-api  合計 2 本 = 表 2 行'
}

@test "dd-gate: 合計 1 行が表の行数とずれると surface-api が FAIL" {
  sedi 's/API 既存拡張 2 本 (Read 1 \/ Write 1)/API 既存拡張 3 本 (Read 1 \/ Write 1)/' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  surface-api'
  printf '%s\n' "$output" | grep -q '^PASS  surface-rw'
}

@test "dd-gate: Read / Write の内訳がずれると surface-rw だけ FAIL" {
  sedi 's/(Read 1 \/ Write 1)/(Read 2 \/ Write 0)/' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  surface-rw'
  printf '%s\n' "$output" | grep -q '^PASS  surface-api'
}

@test "dd-gate: 【未確定】marker が残ると open-marker が FAIL" {
  printf '\n- 上限は【未確定 Q2】\n' >> "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  open-marker'
}

@test "dd-gate: 決める時点が SPEC 作成前の未決 (暫定決定なし) は open-deadline が FAIL" {
  printf '| Q3 | 保存先は Redis か DB か | — | SPEC 作成前 | 開発 |\n' >> "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  open-deadline  作業計画書を止める未決 1 件'
}

@test "dd-gate: 決める時点が作業計画書作成前の未決 (暫定決定なし) は open-deadline が FAIL" {
  printf '| Q3 | 保存先は Redis か DB か | — | 作業計画書作成前 | 開発 |\n' >> "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  open-deadline  作業計画書を止める未決 1 件'
}

@test "dd-gate: 決定事項の表 cell が 160 字を超えると decision-cell が FAIL" {
  long="$(printf 'あ%.0s' $(seq 1 170))"
  sedi "s/| 保存 | 既存 endpoint を拡張する | 新設する |/| 保存 | ${long} | 新設する |/" "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  decision-cell  160 字超の cell 1'
}

@test "dd-gate: 日本語 60 字の cell は byte 数が 160 を超えても decision-cell が PASS" {
  mid="$(printf 'あ%.0s' $(seq 1 60))"
  sedi "s/| 保存 | 既存 endpoint を拡張する | 新設する |/| 保存 | ${mid} | 新設する |/" "$DD"
  run bash "$SCRIPT" "$DD"
  printf '%s\n' "$output" | grep -q '^PASS  decision-cell'
}

@test "dd-gate: 受け入れ条件に file path があると ident が WARN (FAIL にはしない)" {
  sedi 's/名前が空ならサーバは拒否する/`svc\/admin\/thing\/update.go` で拒否する/' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  ident'
}

@test "dd-gate: .go/.ts 以外の拡張子の file 名も ident が WARN" {
  sedi 's/名前が空ならサーバは拒否する/`update_thing.py` で拒否する/' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  ident'
}

# 行を挿入する。$1 = この行の後ろへ入れる、$2 = 入れる行を | で区切ったもの
insert_after() {
  awk -v m="$1" -v ins="$2" '
    { print }
    index($0, m) { n = split(ins, a, "|"); for (i = 1; i <= n; i++) print a[i] }
  ' "$DD" > "${DD}.tmp" && mv "${DD}.tmp" "$DD"
}

@test "dd-gate: 分岐のある条件が 2 行あって振る舞いに図も手順も無いと behavior-diagram が WARN" {
  sedi 's/一覧へ並ぶ/重複した名前なら拒否される/' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  behavior-diagram  分岐のある条件 2 行'
}

@test "dd-gate: 分岐が 2 行でも振る舞いが番号付き手順なら behavior-diagram が PASS" {
  sedi 's/一覧へ並ぶ/重複した名前なら拒否される/' "$DD"
  sedi 's/物の更新は名前の検証を経て保存する。/1. 名前を検証する/' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  behavior-diagram  分岐のある条件 2 行、振る舞いに図か番号付き手順あり'
}

@test "dd-gate: 分岐が 2 行でも振る舞いが mermaid なら behavior-diagram が PASS" {
  sedi 's/一覧へ並ぶ/重複した名前なら拒否される/' "$DD"
  insert_after '物の更新は名前の検証を経て保存する。' '```mermaid|flowchart TB|  A[決済] --> B[取り消し]|```'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  behavior-diagram  分岐のある条件 2 行、振る舞いに図か番号付き手順あり'
}

@test "dd-gate: 分岐が 1 行なら図が無くても behavior-diagram が PASS" {
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  behavior-diagram  分岐のある条件 1 行'
}

@test "dd-gate: 英語の節名 Proposed Design でも振る舞いの図を数える" {
  sedi 's/一覧へ並ぶ/重複した名前なら拒否される/' "$DD"
  sedi 's/^## 6\. 振る舞い$/## 6. Proposed Design › Data Flow/' "$DD"
  insert_after '物の更新は名前の検証を経て保存する。' '```mermaid|stateDiagram-v2|  A --> B|```'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  behavior-diagram  分岐のある条件 2 行、振る舞いに図か番号付き手順あり'
}

@test "dd-gate: 受け入れ条件に曖昧な形容があると vague-adjective が WARN (FAIL にはしない)" {
  sedi 's/名前が空ならサーバは拒否する/名前を堅牢に検証する/' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  vague-adjective  曖昧な形容を含む行 1'
}

@test "dd-gate: 曖昧な形容が無ければ vague-adjective が PASS" {
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  vague-adjective  曖昧な形容 0'
}

# Data Schema の節の末尾 (## 5. の直前) に stdin の内容を差し込む
insert_schema() {
  local block="${BATS_TEST_TMPDIR}/block.md"
  cat > "$block"
  awk -v f="$block" '/^## 5\./ { while ((getline l < f) > 0) print l; print "" } { print }' "$DD" > "${DD}.new" && mv "${DD}.new" "$DD"
}

owner_schema() { # $1 = 先例の行 $2 = 担い手の表の 1 行目の確かめた箇所 $3 = 制約の行 $4 = 確かめた箇所の列名
  local relax="${3:-index / 制約: 論理削除の deleted_at を追加し、注文 ID の UNIQUE を削除する}" col="${4:-確かめた箇所}"
  insert_schema <<EOF
#### 物 (列追加)

- $1
- $relax
- 不変条件の担い手:

| 何を守るか | 今どの仕組みが守るか | 削除する制約が防いでいた場面 | 削除した後の担い手 | $col |
| --- | --- | --- | --- | --- |
| 有効な行は 1 注文 1 件 | UNIQUE | 同時の登録 | 読み取りの条件 | $2 |
EOF
}

@test "dd-gate: 制約を削除も緩和もしない DD は invariant の 2 項目が PASS" {
  run bash "$SCRIPT" "$DD"
  printf '%s\n' "$output" | grep -q '^PASS  invariant-owner  制約の削除・緩和なし'
  printf '%s\n' "$output" | grep -q '^PASS  invariant-precedent  制約の削除・緩和なし'
}

@test "dd-gate: 制約を削除する DD に引き継ぎ先と確かめた箇所、現在 / 撤回の件数があれば PASS" {
  owner_schema '先例: deleted_at を含む UNIQUE は現在 0 件 / 撤回 3 件' '注文を FOR UPDATE'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  invariant-owner  担い手 1 行'
  printf '%s\n' "$output" | grep -q '^PASS  invariant-precedent'
}

@test "dd-gate: 論理削除を含まない制約の緩和 (NOT NULL の解除) でも判定する" {
  owner_schema '先例: 現在 1 件' ' ' 'index / 制約: 担当者 ID の NOT NULL を外し、未割り当てを許す'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  削除・緩和した後の担い手か確かめた箇所が空の行 1'
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-precedent'
}

@test "dd-gate: 制約を削除するのに担い手の表が無ければ FAIL" {
  insert_schema <<EOF
#### 物 (列追加)

- 先例: 現在 0 件 / 撤回 1 件
- index / 制約: 親 ID の外部キーを削除する
EOF
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  制約を削除するか緩めるのに、「削除・緩和した後の担い手」列のある担い手の表が無い'
}

@test "dd-gate: NOT NULL を解除するのに担い手の表が無ければ FAIL (論理削除の語が無くても起動する)" {
  insert_schema <<EOF
#### 物 (列追加)

- 先例: 現在 0 件 / 撤回 1 件
- index / 制約: 担当者 ID の NOT NULL を外し、未割り当てを許す
EOF
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  制約を削除するか緩めるのに'
}

@test "dd-gate: 担い手の表に確かめた箇所の列が無いと invariant-owner が FAIL" {
  owner_schema '先例: 現在 0 件 / 撤回 3 件' '注文を FOR UPDATE' '' '備考'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  担い手の表に「確かめた箇所」列が無い'
  printf '%s\n' "$output" | grep -q '^PASS  invariant-precedent'
}

@test "dd-gate: 以前の列名「登録経路のロック」も確かめた箇所として受ける" {
  owner_schema '先例: 現在 0 件 / 撤回 3 件' '注文を FOR UPDATE' '' '登録経路のロック'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  invariant-owner  担い手 1 行'
}

@test "dd-gate: 確かめた箇所の cell が空だと invariant-owner が FAIL" {
  owner_schema '先例: 現在 0 件 / 撤回 3 件' ' '
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  削除・緩和した後の担い手か確かめた箇所が空の行 1'
}

@test "dd-gate: 先例を撤回の件数なしで数えると invariant-precedent が FAIL" {
  owner_schema '先例: deleted_at を含む UNIQUE は現在 1 件' '注文を FOR UPDATE'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-precedent'
  printf '%s\n' "$output" | grep -q '^PASS  invariant-owner'
}

relax_only_schema() { # $1 = 制約の行
  insert_schema <<EOF
#### 物 (列変更)

- 先例: 現在 0 件 / 撤回 1 件
- $1
EOF
}

@test "dd-gate: nullable にするだけの書き方でも invariant-owner が起動する" {
  relax_only_schema 'index / 制約: user_id を nullable にする'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  制約を削除するか緩めるのに'
}

@test "dd-gate: VARCHAR の長さを広げる書き方でも invariant-owner が起動する" {
  relax_only_schema 'index / 制約: name を VARCHAR(50) から VARCHAR(255) に広げる'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  制約を削除するか緩めるのに'
}

@test "dd-gate: ENUM に値を追加する書き方でも invariant-owner が起動する" {
  relax_only_schema 'index / 制約: status の ENUM に archived を追加する'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  制約を削除するか緩めるのに'
}

@test "dd-gate: PRIMARY KEY の範囲を変える書き方でも invariant-owner が起動する" {
  relax_only_schema 'index / 制約: PRIMARY KEY を (a) から (a,b) に変える'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  制約を削除するか緩めるのに'
}

@test "dd-gate: ON DELETE CASCADE を SET NULL に変える書き方でも invariant-owner が起動する" {
  relax_only_schema 'index / 制約: 親 ID の ON DELETE CASCADE を SET NULL に変える'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  invariant-owner  制約を削除するか緩めるのに'
}

@test "dd-gate: 列と index を追加するだけの Data Schema は invariant-owner が PASS のまま" {
  relax_only_schema 'index / 制約: memo 列を追加し、created_at の index を追加する'
  run bash "$SCRIPT" "$DD"
  printf '%s\n' "$output" | grep -q '^PASS  invariant-owner  制約の削除・緩和なし'
}

@test "dd-gate: 「緩和した後の担い手」列でも担い手の表として検出する" {
  insert_schema <<EOF
#### 物 (列変更)

- 先例: 現在 0 件 / 撤回 1 件
- index / 制約: user_id を nullable にする

| 何を守るか | 今どの仕組みが守るか | 緩和する制約が防いでいた場面 | 緩和した後の担い手 | 確かめた箇所 |
| --- | --- | --- | --- | --- |
| 担当者あり | NOT NULL | 未割り当て | アプリの検証 | service.go:10 |
EOF
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  invariant-owner  担い手 1 行'
}

# API も画面も持たない変更 (CLI / library / batch) の DD は Backend API と Frontend の表を作らない
drop_api_and_screen() {
  awk '/^### Backend API/ || /^### Frontend/ { skip = 1; next } /^#/ { skip = 0 } !skip' "$DD" > "${DD}.new" && mv "${DD}.new" "$DD"
}

@test "dd-gate: API と画面の表が無く合計にも数が無ければ surface の 3 項目が PASS" {
  drop_api_and_screen
  sedi 's/^合計: .*/合計: CLI の subcommand 新規 1、設定 file の key 追加 2、DB 新規 table 1。/' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  surface-api  API の変更なし'
  printf '%s\n' "$output" | grep -q '^PASS  surface-rw  API の変更なし'
  printf '%s\n' "$output" | grep -q '^PASS  surface-screen  画面の変更なし'
}

@test "dd-gate: API と画面の表が無ければ合計 1 行が無くても PASS" {
  drop_api_and_screen
  sedi '/^合計: /d' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  surface-total'
}

@test "dd-gate: API の表があるのに合計 1 行が無ければ surface-total が FAIL" {
  sedi '/^合計: /d' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  surface-total'
}

@test "dd-gate: 表が無いのに合計に API の本数があれば surface-api が FAIL" {
  drop_api_and_screen
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  surface-api  合計 2 本 / 表 0 行'
}

@test "dd-gate: 引数が無いか file が無ければ usage で exit 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" "${BATS_TEST_TMPDIR}/nope.md"
  [ "$status" -eq 2 ]
}
