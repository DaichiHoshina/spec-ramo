#!/usr/bin/env bats
# scripts/select-review-agents.sh: review が起動するエージェントの判定

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/select-review-agents.sh"
  unset SPECRAMO_CONFIG
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO/.specramo"
  printf 'specs_dir: .specramo/specs\n' > "$REPO/.specramo/config.yml"
  export SPECRAMO_REVIEW_DATA_DIR="${BATS_TEST_TMPDIR}/review-data"
}

line() {
  printf '%s\n' "$output" | grep "^$1	"
}

@test "select-review-agents: A は常に run" {
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$(line A | cut -f2)" = "run" ]
}

@test "select-review-agents: 指摘データの dir に file があれば B は run で dir を渡す" {
  mkdir -p "$SPECRAMO_REVIEW_DATA_DIR"
  touch "$SPECRAMO_REVIEW_DATA_DIR/lens.md"
  run bash "$SCRIPT" "$REPO"
  [ "$(line B | cut -f2)" = "run" ]
  [ "$(line B | cut -f3)" = "$SPECRAMO_REVIEW_DATA_DIR" ]
}

@test "select-review-agents: 指摘データの dir が空なら B は skip" {
  mkdir -p "$SPECRAMO_REVIEW_DATA_DIR"
  run bash "$SCRIPT" "$REPO"
  [ "$(line B | cut -f2)" = "skip" ]
  [[ "$(line B | cut -f3)" == *"指摘データが無いため B を省いた"* ]]
}

@test "select-review-agents: 指摘データの dir が無ければ B は skip" {
  run bash "$SCRIPT" "$REPO"
  [ "$(line B | cut -f2)" = "skip" ]
}

@test "select-review-agents: rules の存在する path だけを C に渡し、存在しない path を警告する" {
  mkdir -p "$REPO/docs"
  touch "$REPO/docs/rules.md"
  printf 'rules:\n  - docs/rules.md\n  - docs/missing.md\n' >> "$REPO/.specramo/config.yml"
  run bash "$SCRIPT" "$REPO"
  [ "$(line C | cut -f2)" = "run" ]
  [ "$(line C | cut -f3)" = "docs/rules.md" ]
  [ "$(printf '%s\n' "$output" | grep -c '^warn	C	')" -eq 1 ]
  [[ "$(line warn)" == *"docs/missing.md"* ]]
}

@test "select-review-agents: rules の path が 1 つも存在しなければ C は skip で警告がある" {
  printf 'rules:\n  - docs/missing.md\n' >> "$REPO/.specramo/config.yml"
  run bash "$SCRIPT" "$REPO"
  [ "$(line C | cut -f2)" = "skip" ]
  [ "$(printf '%s\n' "$output" | grep -c '^warn	C	')" -eq 1 ]
}

@test "select-review-agents: rules が未記入で .claude/rules/ も無ければ C は skip で警告が無い" {
  run bash "$SCRIPT" "$REPO"
  [ "$(line C | cut -f2)" = "skip" ]
  ! printf '%s\n' "$output" | grep -q '^warn'
}

@test "select-review-agents: rules が未記入なら .claude/rules/ の file を C に渡す" {
  mkdir -p "$REPO/.claude/rules"
  touch "$REPO/.claude/rules/go.md" "$REPO/.claude/rules/db.md"
  run bash "$SCRIPT" "$REPO"
  [ "$(line C | cut -f2)" = "run" ]
  [ "$(line C | cut -f3)" = ".claude/rules/db.md .claude/rules/go.md" ]
}

@test "select-review-agents: .go を含む差分では D に Go の開発指針 5 本を渡す" {
  run bash "$SCRIPT" "$REPO" README.md pkg/order/order.go
  [ "$(line D | cut -f2)" = "run" ]
  [ "$(line D | cut -f3 | wc -w)" -eq 5 ]
  [[ "$(line D | cut -f3)" == *"/guidelines/languages/golang.md"* ]]
  [[ "$(line D | cut -f3)" != *"typescript.md"* ]]
  for g in $(line D | cut -f3); do [ -f "$g" ]; done
}

@test "select-review-agents: .tsx だけの差分では D に TypeScript の開発指針 1 本を渡す" {
  run bash "$SCRIPT" "$REPO" web/src/App.tsx
  [ "$(line D | cut -f2)" = "run" ]
  [[ "$(line D | cut -f3)" == *"/guidelines/languages/typescript.md" ]]
  [ "$(line D | cut -f3 | wc -w)" -eq 1 ]
}

@test "select-review-agents: .md だけの差分では D は開発指針なしで run" {
  run bash "$SCRIPT" "$REPO" docs/a.md
  [ "$(line D | cut -f2)" = "run" ]
  [ -z "$(line D | cut -f3)" ]
}

@test "select-review-agents: 対応表に行が無い拡張子 (.py) だけの差分では D は開発指針なしで run" {
  run bash "$SCRIPT" "$REPO" tools/gen.py
  [ "$(line D | cut -f2)" = "run" ]
  [ -z "$(line D | cut -f3)" ]
}

@test "select-review-agents: .go と .ts を含む差分では D に両方の指針を重複なしで渡す" {
  run bash "$SCRIPT" "$REPO" a.go b.go web/c.ts web/d.mts
  [ "$(line D | cut -f3 | wc -w)" -eq 6 ]
  [ "$(line D | cut -f3 | tr ' ' '\n' | sort | uniq -d | wc -l)" -eq 0 ]
}

@test "select-review-agents: 対応表に書いた開発指針の file はすべて実在する" {
  tsv="${BATS_TEST_DIRNAME}/../guidelines/languages/extensions.tsv"
  [ -f "$tsv" ]
  for g in $(grep -v '^#' "$tsv" | cut -f2); do
    [ -f "${BATS_TEST_DIRNAME}/../guidelines/languages/$g" ] || { echo "missing: $g"; false; }
  done
}

@test "select-review-agents: 設定 file が無ければ 2" {
  run bash "$SCRIPT" "${BATS_TEST_TMPDIR}"
  [ "$status" -eq 2 ]
}
