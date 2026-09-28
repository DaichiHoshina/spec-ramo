#!/usr/bin/env bats
# examples/: サンプル機能の成果物が、同梱の検査 script を FAIL 0 で満たす

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  EX="$ROOT/examples/overdue-todos"
  # 検査の結果を導入先の設定に左右されないよう、初期値の設定 file を使う
  export SPECRAMO_CONFIG="$ROOT/templates/config.yml"
}

@test "examples: 成果物一式と README がそろっている" {
  for f in prd.md design.md plan.md plan-phase1.md README.md; do
    [ -f "$EX/$f" ] || { echo "無い: $f"; return 1; }
  done
}

@test "examples: Design Doc が Design Doc 検査で FAIL 0" {
  run bash "$ROOT/scripts/dd-gate.sh" "$EX/design.md"
  echo "$output"
  [ "$status" -eq 0 ]
  ! printf '%s\n' "$output" | grep -q '^FAIL'
}

@test "examples: 作業計画書が作業計画書検査で FAIL 0" {
  run bash "$ROOT/scripts/spec-gate.sh" "$EX/plan.md"
  echo "$output"
  [ "$status" -eq 0 ]
  ! printf '%s\n' "$output" | grep -q '^FAIL'
}

@test "examples: 作業計画書に Phase の状態の表がある" {
  run bash "$ROOT/scripts/phase-state.sh" get "$EX/plan.md" 1
  [ "$status" -eq 0 ]
}
