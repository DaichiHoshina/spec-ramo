#!/usr/bin/env bats
# scripts/require-config.sh: init 以外のコマンドの前提確認

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/require-config.sh"
  unset SPECRAMO_CONFIG
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO/a"
}

@test "require-config: 設定 file があれば path を表示して 0" {
  mkdir -p "$REPO/.specramo"
  touch "$REPO/.specramo/config.yml"
  run bash "$SCRIPT" "$REPO/a"
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.specramo/config.yml" ]
}

@test "require-config: 設定 file が無ければ init を案内して 2" {
  run bash "$SCRIPT" "$REPO/a"
  [ "$status" -eq 2 ]
  [[ "$output" == *"/specramo:init を実行してください"* ]]
}
