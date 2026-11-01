#!/usr/bin/env bats
# scripts/init.sh: 導入先の初期化。すでにある file は変更しない

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$ROOT/scripts/init.sh"
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO"
}

# dir 以下の全 file の path と hash を並べる (実行前後の比較に使う)
snapshot() {
  (cd "$1" && find . -type f -print0 | sort -z | xargs -0 cksum; find . -type d | sort)
}

@test "init: 空の dir に設定 file と成果物の置き場所を作る" {
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.sdd/config.yml" ]
  [ -d "$REPO/.sdd/specs" ]
  [ "${lines[0]}" = "作った: .sdd/config.yml" ]
  [ "${lines[1]}" = "作った: .sdd/specs/" ]
  cmp "$REPO/.sdd/config.yml" "$ROOT/templates/config.yml"
}

@test "init: 両方があれば何も変えず、作らなかった file の名前を表示する" {
  mkdir -p "$REPO/.sdd/specs/feature"
  printf 'max_lines: 200\n' > "$REPO/.sdd/config.yml"
  printf 'x\n' > "$REPO/.sdd/specs/feature/prd.md"
  before="$(snapshot "$REPO")"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$(snapshot "$REPO")" = "$before" ]
  [ "${lines[0]}" = "作らなかった (すでにある): .sdd/config.yml" ]
  [ "${lines[1]}" = "作らなかった (すでにある): .sdd/specs/" ]
}

@test "init: 設定 file だけがあれば、成果物の置き場所だけを作る" {
  mkdir -p "$REPO/.sdd"
  printf 'max_lines: 200\n' > "$REPO/.sdd/config.yml"
  hash_before="$(cksum < "$REPO/.sdd/config.yml")"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ -d "$REPO/.sdd/specs" ]
  [ "$(cksum < "$REPO/.sdd/config.yml")" = "$hash_before" ]
  [ "${lines[0]}" = "作らなかった (すでにある): .sdd/config.yml" ]
  [ "${lines[1]}" = "作った: .sdd/specs/" ]
}

@test "init: 引数が無ければ git の repo root を対象にする" {
  git -C "$REPO" init -q
  mkdir -p "$REPO/sub/dir"
  cd "$REPO/sub/dir"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.sdd/config.yml" ]
  [ ! -e "$REPO/sub/dir/.sdd" ]
}
