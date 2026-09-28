#!/usr/bin/env bats
# scripts/resolve-template.sh: 導入先に同じ名前の雛形があればそれを、無ければ plugin の雛形を使う

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$ROOT/scripts/resolve-template.sh"
  unset SPECRAMO_CONFIG
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO/.specramo/templates"
  touch "$REPO/.specramo/config.yml"
}

@test "resolve-template: 導入先に同じ名前の file があればその path" {
  printf '# 独自の雛形\n' > "$REPO/.specramo/templates/design.md"
  run bash "$SCRIPT" design "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.specramo/templates/design.md" ]
}

@test "resolve-template: 導入先に無ければ plugin の雛形の path" {
  run bash "$SCRIPT" plan "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "$ROOT/templates/plan.md" ]
  [ -f "$output" ]
}

@test "resolve-template: 4 つの名前の plugin の雛形がすべて実在する" {
  for n in prd design plan phase-design; do
    run bash "$SCRIPT" "$n" "$REPO"
    [ "$status" -eq 0 ]
    [ -f "$output" ]
  done
}

@test "resolve-template: 知らない名前は 2" {
  run bash "$SCRIPT" readme "$REPO"
  [ "$status" -eq 2 ]
}

@test "resolve-template: 作業計画書の雛形に Phase の状態の表がある" {
  grep -q '^## Phase の状態' "$ROOT/templates/plan.md"
  grep -q '^| PR | Phase 名 | 状態 | 説明 |' "$ROOT/templates/plan.md"
}
