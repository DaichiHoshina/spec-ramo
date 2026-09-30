#!/usr/bin/env bats
# dd-gate.sh: spec 型 DD の script 判定 6 項目。良い fixture で PASS し、条件を 1 つ壊すと該当項目だけ FAIL することを見る。

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

soft_delete_schema() { # $1 = 先例の行 $2 = 担い手の表の 1 行目の lock cell
  insert_schema <<EOF
#### 物 (列追加)

- $1
- index / 制約: 論理削除の deleted_at を追加し、注文 ID の UNIQUE を削除する
- 不変条件の担い手:

| 何を守るか | 今どの仕組みが守るか | 削除する制約が防いでいた場面 | 削除した後の担い手 | 登録経路のロック |
| --- | --- | --- | --- | --- |
| 有効な行は 1 注文 1 件 | UNIQUE | 同時の登録 | 読み取りの条件 | $2 |
EOF
}

@test "dd-gate: 論理削除と一意性の組が無い DD は soft-delete の 2 項目が PASS" {
  run bash "$SCRIPT" "$DD"
  printf '%s\n' "$output" | grep -q '^PASS  soft-delete-lock  論理削除と一意性の組なし'
  printf '%s\n' "$output" | grep -q '^PASS  soft-delete-precedent  論理削除と一意性の組なし'
}

@test "dd-gate: 論理削除と一意性の担い手に登録経路のロックと現在 / 撤回の件数があれば PASS" {
  soft_delete_schema '先例: deleted_at を含む UNIQUE は現在 0 件 / 撤回 3 件' '注文を FOR UPDATE'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  soft-delete-lock  担い手 1 行'
  printf '%s\n' "$output" | grep -q '^PASS  soft-delete-precedent'
}

@test "dd-gate: 論理削除と一意性の担い手に登録経路のロック列が無いと soft-delete-lock が FAIL" {
  soft_delete_schema '先例: 現在 0 件 / 撤回 3 件' '注文を FOR UPDATE'
  sedi 's/ | 登録経路のロック |/ | 備考 |/' "$DD"
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  soft-delete-lock  担い手の表に「登録経路のロック」列が無い'
  printf '%s\n' "$output" | grep -q '^PASS  soft-delete-precedent'
}

@test "dd-gate: 登録経路のロックの cell が空だと soft-delete-lock が FAIL" {
  soft_delete_schema '先例: 現在 0 件 / 撤回 3 件' ' '
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  soft-delete-lock  登録経路のロックが空の行 1'
}

@test "dd-gate: 先例を撤回の件数なしで数えると soft-delete-precedent が FAIL" {
  soft_delete_schema '先例: deleted_at を含む UNIQUE は現在 1 件' '注文を FOR UPDATE'
  run bash "$SCRIPT" "$DD"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  soft-delete-precedent'
  printf '%s\n' "$output" | grep -q '^PASS  soft-delete-lock'
}

@test "dd-gate: 引数が無いか file が無ければ usage で exit 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" "${BATS_TEST_TMPDIR}/nope.md"
  [ "$status" -eq 2 ]
}
