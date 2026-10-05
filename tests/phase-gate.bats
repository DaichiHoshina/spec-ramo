#!/usr/bin/env bats
# table-readers.sh と phase-gate.sh: table を読む query を全件数えることと、
# 意味が変わる table の宣言・件数の一致・query ごとの扱いの判定。

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  READERS="${PROJECT_ROOT}/scripts/table-readers.sh"
  GATE="${PROJECT_ROOT}/scripts/phase-gate.sh"
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO/pkg/reader" "$REPO/admin" "$REPO/migrations" "$REPO/.specramo/specs/f"
  cat > "$REPO/pkg/reader/item.go" <<'EOF'
q := "SELECT id FROM items WHERE order_id = ?"
q2 := "SELECT id FROM items_archive WHERE id = ?"
EOF
  cat > "$REPO/admin/report.go" <<'EOF'
LEFT JOIN `items` ON items.order_id = orders.id
EOF
  printf 'q := "SELECT id FROM items"\n' > "$REPO/pkg/reader/item_test.go"
  printf 'ALTER TABLE items ADD COLUMN deleted_at DATETIME;\nSELECT 1 FROM items;\n' > "$REPO/migrations/1_.up.sql"
  git -C "$REPO" init -q
  git -C "$REPO" add -A
  DOC="$REPO/.specramo/specs/f/plan-phase1.md"
}

write_doc() { # $1 = 節に記載する件数、$2 = 扱いの行数 (省略時は $1 と同じ)、$3 = 意味が変わる table の宣言 (省略時は items)
  local decided="${2:-$1}" decl="${3:-\`items\`}" i
  {
    printf '# Phase 詳細設計\n\n1. 状態に「保留」を追加し、一覧から除く\n\n'
    printf '意味が変わる table: %s\n\n' "$decl"
    printf '## 実装メモ\n\n### table を読む query\n\n'
    printf 'table: `items`\n'
    printf 'pkg/reader/item.go:1: q := "SELECT id FROM items WHERE order_id = ?"\n'
    for ((i = 0; i < decided; i++)); do
      echo "- 扱い: 変更する (保留の行を除く条件を追加する)"
    done
    echo "合計 $1 件"
  } > "$DOC"
}

@test "table-readers: FROM と JOIN の行を数え、test と migration と別名の table を除く" {
  run bash "$READERS" "$REPO" items
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | tail -1)" = "合計 2 件" ]
  printf '%s\n' "$output" | grep -q '^admin/report.go:1:'
  printf '%s\n' "$output" | grep -q '^pkg/reader/item.go:1:'
  ! printf '%s\n' "$output" | grep -q 'items_archive'
  ! printf '%s\n' "$output" | grep -qE '_test|migrations'
  printf '%s\n' "$output" | grep -q '^注: SQL の文字列 (FROM / JOIN) だけを数える'
}

@test "table-readers: 引数が足りないか table 名に記号があれば usage で exit 2" {
  run bash "$READERS" "$REPO"
  [ "$status" -eq 2 ]
  run bash "$READERS" "$REPO" 'items;x'
  [ "$status" -eq 2 ]
}

@test "phase-gate: 意味が変わる table の宣言が無ければ FAIL" {
  printf '# Phase 詳細設計\n\n1. 一覧に列を追加する\n' > "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  declaration  「意味が変わる table: <table 名> / なし」の行が無い'
}

@test "phase-gate: 意味が変わる table が なし なら、節が無くても PASS" {
  printf '# Phase 詳細設計\n\n1. 一覧に列を追加する\n\n- 意味が変わる table: なし\n' > "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  declaration  意味が変わる table なし'
}

@test "phase-gate: 宣言の table 名に記号があれば FAIL" {
  write_doc 2 2 'items; drop'
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  declaration  「items;」は table 名として読めない'
}

@test "phase-gate: 節の件数が改めて数えた件数と一致すれば PASS" {
  write_doc 2
  run bash "$GATE" "$DOC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  table-readers  items: 合計 2 件'
}

@test "phase-gate: 節の件数が実物より少なければ FAIL" {
  write_doc 1
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  table-readers  items: 節は 1 件、改めて数えると 2 件'
}

@test "phase-gate: 宣言したのに「table を読む query」の節が無ければ FAIL" {
  printf '# Phase 詳細設計\n\n意味が変わる table: items\n' > "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  table-readers  「table を読む query」の節が無い'
}

@test "phase-gate: 宣言した table の行が節に無ければ FAIL" {
  write_doc 2
  sed -i.bak '/^table:/d' "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  table-readers  items: 節に「table: items」の行が無い'
}

@test "phase-gate: 宣言した table が 2 つなら、節に無い方だけ FAIL" {
  write_doc 2 2 'items, orders'
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^PASS  table-readers  items: 合計 2 件'
  printf '%s\n' "$output" | grep -q '^FAIL  table-readers  orders: 節に「table: orders」の行が無い'
}

@test "phase-gate: 件数が合い、query ごとに扱いがあれば decision も PASS" {
  write_doc 2
  run bash "$GATE" "$DOC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  table-readers-decision  items: 扱いを 2 件記載 (query 2 件)'
}

@test "phase-gate: 扱いが query の件数に足りなければ FAIL" {
  write_doc 2 1
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  table-readers-decision  items: 扱いが 1 件、query は 2 件'
}

@test "phase-gate: 扱いの値が規定外か根拠が無ければ数えず FAIL" {
  write_doc 2 0
  { echo "- 扱い: 未定"; echo "- 扱い: 変更しない"; } >> "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  table-readers-decision  items: 扱いが 0 件、query は 2 件'
}

@test "phase-gate: 変更しないと根拠があれば数える (全角の括弧も数える)" {
  write_doc 2 0
  { echo "- 扱い: 変更しない (管理画面は保留の行も表示するため)"; echo "- 扱い: 変更する（一覧から保留の行を除く）"; } >> "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  table-readers-decision  items: 扱いを 2 件記載'
}

@test "phase-gate: 以前の形の「複数行の扱い」も扱いとして数える" {
  write_doc 2 0
  { echo "- 複数行の扱い: 最新 1 件だけを対象にする (ORDER BY id DESC LIMIT 1)"; echo "- 複数行の扱い: 1 件以下が保証される (登録経路の行ロック)"; } >> "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  table-readers-decision  items: 扱いを 2 件記載'
}

@test "phase-gate: 名前が前方一致する別の table の節にある扱いは数えない" {
  write_doc 2 0
  printf 'table: items_archive\n- 扱い: 変更する (別 table)\n- 扱い: 変更する (別 table)\n' >> "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  table-readers-decision  items: 扱いが 0 件'
}

@test "phase-gate: 引数が無いか file が無ければ usage で exit 2" {
  run bash "$GATE"
  [ "$status" -eq 2 ]
  run bash "$GATE" "${BATS_TEST_TMPDIR}/nope.md"
  [ "$status" -eq 2 ]
}

@test "phase-gate: 設計書が repo の外にあっても、cwd が repo の中なら cwd の repo で数える" {
  write_doc 2
  OUT="${BATS_TEST_TMPDIR}/plans"
  mkdir -p "$OUT"
  mv "$DOC" "$OUT/plan-phase1.md"
  cd "$REPO"
  run bash "$GATE" "$OUT/plan-phase1.md"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  table-readers  items: 合計 2 件'
}

@test "phase-gate: 設計書の dir も cwd も repo の外なら FAIL" {
  write_doc 2
  OUT="${BATS_TEST_TMPDIR}/plans"
  mkdir -p "$OUT"
  mv "$DOC" "$OUT/plan-phase1.md"
  cd "$OUT"
  GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run bash "$GATE" "$OUT/plan-phase1.md"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q 'cwd も git の repo の外'
}
