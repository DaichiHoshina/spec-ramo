#!/usr/bin/env bats
# scripts/status.sh: 機能ごとの Phase の進み具合の表示と、PR 作成済みへの遷移

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$ROOT/scripts/status.sh"
  unset SPECRAMO_CONFIG
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO/.specramo/specs/no-plan" "$REPO/.specramo/specs/todos"
  printf 'specs_dir: .specramo/specs\n' > "$REPO/.specramo/config.yml"
  git -C "$REPO" init -q
  git -C "$REPO" remote add origin https://github.com/example/todos.git
  PLAN="$REPO/.specramo/specs/todos/plan.md"
  cat > "$PLAN" <<'EOF'
# 作業計画書: todos

## Phase の状態

| PR | Phase 名 | 状態 | 説明 |
| --- | --- | --- | --- |
| #1 | 一覧 | 実装中 | |
| #2 | 通知 | レビュー済み | 2026-09-20 |

## PR 分割計画

### PR #1: 一覧

- 依存: なし
- branch: `phase/1-list`

### PR #2: 通知

- 依存: PR #1
- branch: `phase/2-notify`
EOF
  # PR の有無を返す stub。呼ばれた branch を記録する
  STUB="${BATS_TEST_TMPDIR}/gh-stub"
  CALLS="${BATS_TEST_TMPDIR}/calls"
  : > "$CALLS"
  cat > "$STUB" <<EOF
#!/usr/bin/env bash
echo "\$4" >> "$CALLS"
case "\${STUB_MODE:-found}" in
  found) echo '[{"number":12}]' ;;
  none) echo '[]' ;;
  fail) exit 1 ;;
esac
EOF
  chmod +x "$STUB"
  export SPECRAMO_GH="$STUB"
}

@test "status: 先頭に plugin の version を表示する" {
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  version="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json")"
  [ "${lines[0]}" = "specramo $version" ]
}

@test "status: 作業計画書が無い機能では plan の実行を案内する" {
  run bash "$SCRIPT" "$REPO"
  [[ "$output" == *"no-plan: 作業計画書がありません。/specramo:plan を実行してください"* ]]
}

@test "status: 作業計画書がある機能では Phase の状態の行を表示する" {
  STUB_MODE=none run bash "$SCRIPT" "$REPO"
  [[ "$output" == *"| #1 | 一覧 | 実装中 | |"* ]]
  [[ "$output" == *"| #2 | 通知 | レビュー済み | 2026-09-20 |"* ]]
}

@test "status: PR があればレビュー済みの行だけ PR 作成済みにし、実装中の行は問い合わせない" {
  STUB_MODE=found run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| #2 | 通知 | PR 作成済み | 2026-09-20 |"* ]]
  grep -q '^| #1 | 一覧 | 実装中 | |$' "$PLAN"
  grep -q '^| #2 | 通知 | PR 作成済み | 2026-09-20 |$' "$PLAN"
  [ "$(cat "$CALLS")" = "phase/2-notify" ]
}

@test "status: GitHub に問い合わせられないときは状態を変えず、確認できなかった旨を表示する" {
  before="$(cksum < "$PLAN")"
  STUB_MODE=fail run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"#2: GitHub に問い合わせられず、PR の有無を確認できなかった"* ]]
  [ "$(cksum < "$PLAN")" = "$before" ]
  [[ "$output" == *"| #2 | 通知 | レビュー済み | 2026-09-20 |"* ]]
}

@test "status: GitHub の remote が無いときは gh に問い合わせず、remote が無い旨を表示する" {
  git -C "$REPO" remote remove origin
  before="$(cksum < "$PLAN")"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"#2: GitHub の remote が無いため、PR の有無を確認できなかった"* ]]
  [ ! -s "$CALLS" ]
  [ "$(cksum < "$PLAN")" = "$before" ]
}

@test "status: gh が無い環境でも表示を続ける" {
  SPECRAMO_GH="${BATS_TEST_TMPDIR}/no-such-gh" run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR の有無を確認できなかった"* ]]
  [[ "$output" == *"| #1 | 一覧 | 実装中 | |"* ]]
}

@test "status: pr_check_command があれば gh でなくその command で PR を確かめる" {
  CHECK="${BATS_TEST_TMPDIR}/check.sh"
  printf '#!/usr/bin/env bash\necho "$1" >> "%s"\necho "!12"\n' "$CALLS" > "$CHECK"
  printf 'pr_check_command: bash %s {branch}\n' "$CHECK" >> "$REPO/.specramo/config.yml"
  git -C "$REPO" remote remove origin
  SPECRAMO_GH="${BATS_TEST_TMPDIR}/no-such-gh" run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "phase/2-notify" ]
  grep -q '| #2 | 通知 | PR 作成済み |' "$PLAN"
}

@test "status: pr_check_command が何も表示しなければ状態を変えない" {
  printf 'pr_check_command: "true {branch}"\n' >> "$REPO/.specramo/config.yml"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  grep -q '| #2 | 通知 | レビュー済み |' "$PLAN"
  ! printf '%s\n' "$output" | grep -q '確認できなかった'
}

@test "status: pr_check_command が失敗したら状態を変えず、確認できなかった旨を表示する" {
  printf 'pr_check_command: "false {branch}"\n' >> "$REPO/.specramo/config.yml"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  grep -q '| #2 | 通知 | レビュー済み |' "$PLAN"
  [[ "$output" == *"#2: pr_check_command が失敗し"* ]]
}

@test "status: pr_check_command の branch 名は shell に解釈させない" {
  sed -i.bak 's/phase\/2-notify/phase\/2-$(touch pwned)/' "$PLAN"
  printf 'pr_check_command: "printf %%s {branch} > %s"\n' "${BATS_TEST_TMPDIR}/got" >> "$REPO/.specramo/config.yml"
  run bash "$SCRIPT" "$REPO"
  [ ! -e "$REPO/pwned" ]
  [ "$(cat "${BATS_TEST_TMPDIR}/got")" = 'phase/2-$(touch pwned)' ]
}

@test "status: 設定 file が無ければ 2" {
  run bash "$SCRIPT" "${BATS_TEST_TMPDIR}"
  [ "$status" -eq 2 ]
}
