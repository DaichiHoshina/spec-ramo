#!/usr/bin/env bats
# scripts/lib/config.sh: 導入先の設定 file の場所の決め方と、値の読み出し

setup() {
  LIB="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/lib/config.sh"
  unset SPECRAMO_CONFIG
  CONF="${BATS_TEST_TMPDIR}/config.yml"
  cat > "$CONF" <<'EOF'
# 導入先の設定
specs_dir: .specramo/specs
max_lines: 300   # 1 PR の上限
branch_pattern: "<issue>-<PR>"
test_paths:
  - "**/*_test.go"
  - tests/

rules:
EOF
}

@test "config: 1 行の値を読む。引用符と行末の comment は含めない" {
  run bash -c ". '$LIB'; specramo_config_get '$CONF' max_lines; specramo_config_get '$CONF' branch_pattern"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "300" ]
  [ "${lines[1]}" = "<issue>-<PR>" ]
}

@test "config: 両端が同じ引用符でない値は、末尾の引用符を値の一部として残す" {
  printf '%s\n' "pr_check_command: glab mr list --source-branch {branch} | jq '.[].iid'" >> "$CONF"
  run bash -c ". '$LIB'; specramo_config_get '$CONF' pr_check_command"
  [ "$status" -eq 0 ]
  [ "$output" = "glab mr list --source-branch {branch} | jq '.[].iid'" ]
}

@test "config: list の値を 1 行 1 要素で読む" {
  run bash -c ". '$LIB'; specramo_config_get '$CONF' test_paths"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "**/*_test.go" ]
  [ "${lines[1]}" = "tests/" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "config: key が無いか、値が空の list なら終了コード 1" {
  run bash -c ". '$LIB'; specramo_config_get '$CONF' absent"
  [ "$status" -eq 1 ]
  run bash -c ". '$LIB'; specramo_config_get '$CONF' rules"
  [ "$status" -eq 1 ]
}

@test "config: 設定 file の場所は環境変数を優先し、無ければ上の dir へたどって探す" {
  mkdir -p "${BATS_TEST_TMPDIR}/repo/.specramo" "${BATS_TEST_TMPDIR}/repo/a/b"
  touch "${BATS_TEST_TMPDIR}/repo/.specramo/config.yml"
  run bash -c ". '$LIB'; specramo_config_path '${BATS_TEST_TMPDIR}/repo/a/b'"
  [ "$status" -eq 0 ]
  [ "$output" = "${BATS_TEST_TMPDIR}/repo/.specramo/config.yml" ]
  run bash -c "SPECRAMO_CONFIG='$CONF'; . '$LIB'; specramo_config_path '${BATS_TEST_TMPDIR}/repo/a/b'"
  [ "$output" = "$CONF" ]
}

@test "config: 設定 file が見つからなければ終了コード 1" {
  mkdir -p "${BATS_TEST_TMPDIR}/empty"
  run bash -c ". '$LIB'; specramo_config_path '${BATS_TEST_TMPDIR}/empty'"
  [ "$status" -eq 1 ]
}
