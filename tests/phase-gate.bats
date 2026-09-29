#!/usr/bin/env bats
# table-readers.sh と phase-gate.sh: table を読む query を全件数えることと、Phase 詳細設計の件数が実物と一致するかの判定。

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

write_doc() { # $1 = 節に記載する件数
  cat > "$DOC" <<EOF
# Phase 詳細設計

1. 論理削除した行を読み取りから除く

## 実装メモ

### table を読む query

table: \`items\`
pkg/reader/item.go:1: q := "SELECT id FROM items WHERE order_id = ?"
合計 $1 件
EOF
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

@test "phase-gate: 論理削除を扱わない詳細設計は PASS" {
  printf '# Phase 詳細設計\n\n1. 一覧に列を追加する\n' > "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  table-readers  行の意味が変わる変更なし'
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

@test "phase-gate: 論理削除を扱うのに「table を読む query」の節が無ければ FAIL" {
  printf '# Phase 詳細設計\n\n1. deleted_at を条件に追加する\n' > "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  table-readers  「table を読む query」の節が無い'
}

@test "phase-gate: 節に table 名の行が無ければ FAIL" {
  write_doc 2
  sed -i.bak '/^table:/d' "$DOC"
  run bash "$GATE" "$DOC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  table-readers  節に「table: <table 名>」の行が無い'
}

@test "phase-gate: 引数が無いか file が無ければ usage で exit 2" {
  run bash "$GATE"
  [ "$status" -eq 2 ]
  run bash "$GATE" "${BATS_TEST_TMPDIR}/nope.md"
  [ "$status" -eq 2 ]
}
