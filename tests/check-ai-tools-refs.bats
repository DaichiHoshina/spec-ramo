#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-ai-tools-refs.sh"
  WORK="$(mktemp -d)"
}

teardown() {
  rm -rf "$WORK"
}

@test "空の dir は 0 件で終了コード 0" {
  run "$SCRIPT" "$WORK"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
}

@test "~/.claude/ を含む file があると終了コード 1" {
  printf 'Read ~/.claude/rules/x.md\n' > "$WORK/skill.md"
  run "$SCRIPT" "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  ai-tools-refs  1 件"* ]]
  [[ "$output" == *"skill.md:1:"* ]]
}

@test "\$HOME/.claude と ai-tools と references-private をそれぞれ検出する" {
  printf 'a $HOME/.claude/x\n' > "$WORK/a.sh"
  printf 'b ai-tools の手順\n' > "$WORK/b.md"
  printf 'c references-private/x\n' > "$WORK/c.md"
  run "$SCRIPT" "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"3 件"* ]]
}

@test "引数が無いときは repo の同梱 dir を検査し、この script 自身は数えない" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
}
