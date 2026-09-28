#!/usr/bin/env bats
# scripts/phase-state.sh: 作業計画書の「Phase の状態」の表の読み書き

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/phase-state.sh"
  PLAN="${BATS_TEST_TMPDIR}/plan.md"
  cat > "$PLAN" <<'EOF'
# 作業計画書: テスト

| #1 | 表の外の行 | 未着手 | |

## Phase の状態

| PR | Phase 名 | 状態 | 説明 |
| --- | --- | --- | --- |
| #1 | 一覧 | 未着手 | |
| #2 | 通知 | 実装中 | |
| #3 | 設定 | レビュー済み | 2026-09-01 |

## PR 分割計画

| #1 | 表の外の行 | 未着手 | |
EOF
}

@test "phase-state: get は行の状態を表示する (# の有無を問わない)" {
  run bash "$SCRIPT" get "$PLAN" 2
  [ "$status" -eq 0 ]
  [ "$output" = "実装中" ]
  run bash "$SCRIPT" get "$PLAN" "#3"
  [ "$output" = "レビュー済み" ]
}

@test "phase-state: 未着手を実装中にすると成功し、他の行と表の外は変わらない" {
  cp "$PLAN" "${BATS_TEST_TMPDIR}/before.md"
  run bash "$SCRIPT" set "$PLAN" 1 実装中
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" get "$PLAN" 1
  [ "$output" = "実装中" ]
  run diff "${BATS_TEST_TMPDIR}/before.md" "$PLAN"
  [ "$(printf '%s\n' "$output" | grep -c '^[<>]')" -eq 2 ]
  [[ "$output" == *"> | #1 | 一覧 | 実装中 | |"* ]]
}

@test "phase-state: 未着手を PR 作成済みにすると 3 で、file は変わらない" {
  before="$(cksum < "$PLAN")"
  run bash "$SCRIPT" set "$PLAN" 1 "PR 作成済み"
  [ "$status" -eq 3 ]
  [[ "$output" == *"未着手 から PR 作成済み には進めない"* ]]
  [ "$(cksum < "$PLAN")" = "$before" ]
}

@test "phase-state: 6.2 の遷移だけを許す" {
  run bash "$SCRIPT" set "$PLAN" 2 実装中
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" set "$PLAN" 2 レビュー済み
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" set "$PLAN" 2 レビュー済み
  [ "$status" -eq 3 ]
  run bash "$SCRIPT" set "$PLAN" 3 "PR 作成済み"
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" set "$PLAN" 3 実装中
  [ "$status" -eq 3 ]
}

@test "phase-state: 説明列の記録を 2 回すると 2 回目の日付で上書きされ、状態は変わらない" {
  bash "$SCRIPT" explained "$PLAN" 3 2026-09-10
  bash "$SCRIPT" explained "$PLAN" 3 2026-09-11
  grep -q '^| #3 | 設定 | レビュー済み | 2026-09-11 |$' "$PLAN"
  ! grep -q '2026-09-10' "$PLAN"
}

@test "phase-state: 表に無い PR 番号は 2" {
  run bash "$SCRIPT" get "$PLAN" 9
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" set "$PLAN" 9 実装中
  [ "$status" -eq 2 ]
}

@test "phase-state: 表の節が無い作業計画書は 2" {
  printf '# 作業計画書\n\n| #1 | a | 未着手 | |\n' > "$PLAN"
  run bash "$SCRIPT" get "$PLAN" 1
  [ "$status" -eq 2 ]
}
