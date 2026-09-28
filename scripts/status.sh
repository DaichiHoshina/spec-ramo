#!/usr/bin/env bash
# 機能ごとの Phase の進み具合を表示する。成果物の置き場所 (specs_dir) の下の dir を 1 つずつ
# 機能として扱い、作業計画書の「Phase の状態」の表を表示する。
# 状態がレビュー済みの Phase だけ、branch の PR が GitHub にあるかを確かめ、あれば状態を
# PR 作成済みにしてから表示する。
# 引数: 設定 file を探し始める dir (省略時は current dir)
# 環境変数: SPECRAMO_GH (GitHub への問い合わせに使う command。初期値は gh)
set -u

here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib/config.sh"
plugin_root="$(dirname "$here")"
gh_cmd="${SPECRAMO_GH:-gh}"

config="$(specramo_config_path "${1:-.}")" || {
  echo "設定 file (.specramo/config.yml) がありません。/specramo:init を実行してください"
  exit 2
}
repo_root="$(dirname "$(dirname "$config")")"
specs_dir="$(specramo_config_get "$config" specs_dir)" || specs_dir=".specramo/specs"
case "$specs_dir" in /*) ;; *) specs_dir="$repo_root/$specs_dir" ;; esac

# GitHub の remote が無い repo では gh に問い合わせても PR は見つからないので、理由を分けて表示する
has_github_remote=0
git -C "$repo_root" remote -v 2>/dev/null | grep -q 'github\.com' && has_github_remote=1

version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$plugin_root/.claude-plugin/plugin.json" | head -1)"
echo "specramo ${version:-不明}"

# 「Phase の状態」の表の行 (見出し行と区切り行を除く) を表示する
state_rows() {
  awk '
    /^##+ / { in_sec = ($0 ~ /^##+ Phase の状態[ \t]*$/); next }
    in_sec && /^\|/ {
      n = split($0, c, "|")
      v = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v ~ /^#[0-9]/) print
    }
  ' "$1"
}

# PR 見出し (### PR #n / #### PR #n) の直下の「branch:」の値を表示する
branch_of() {
  awk -v pr="$2" '
    /^###+ / {
      in_pr = 0
      h = $0; sub(/^###+[ \t]+/, "", h)
      if (h ~ /^PR[ \t]+#/) { sub(/^PR[ \t]+/, "", h); sub(/[^#0-9].*$/, "", h); in_pr = (h == pr) }
      next
    }
    in_pr && /^[ \t]*-[ \t]*branch:/ {
      v = $0; sub(/^[ \t]*-[ \t]*branch:[ \t]*/, "", v); gsub(/`/, "", v); sub(/[ \t]+$/, "", v)
      print v; exit
    }
  ' "$1"
}

col() {
  printf '%s\n' "$1" | awk -v i="$2" -F'|' '{ v = $(i + 1); gsub(/^[ \t]+|[ \t]+$/, "", v); print v }'
}

if [ ! -d "$specs_dir" ] || [ -z "$(find "$specs_dir" -mindepth 1 -maxdepth 1 -type d | head -1)" ]; then
  echo "成果物がまだありません。/specramo:prd から始めてください"
  exit 0
fi

for dir in "$specs_dir"/*/; do
  feature="$(basename "$dir")"
  plan="${dir}plan.md"
  echo
  if [ ! -f "$plan" ]; then
    echo "$feature: 作業計画書がありません。/specramo:plan を実行してください"
    continue
  fi
  echo "$feature"

  # レビュー済みの Phase だけ PR の有無を確かめる
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    [ "$(col "$row" 3)" = "レビュー済み" ] || continue
    pr="$(col "$row" 1)"
    branch="$(branch_of "$plan" "$pr")"
    if [ -z "$branch" ]; then
      echo "  $pr: 作業計画書に branch 名が無いため、PR の有無を確認できなかった"
      continue
    fi
    if [ "$has_github_remote" -eq 0 ]; then
      echo "  $pr: GitHub の remote が無いため、PR の有無を確認できなかった"
      continue
    fi
    if ! out="$("$gh_cmd" pr list --head "$branch" --state all --json number 2>/dev/null)"; then
      echo "  $pr: GitHub に問い合わせられず、PR の有無を確認できなかった"
      continue
    fi
    if printf '%s\n' "$out" | grep -q '"number"'; then
      bash "$here/phase-state.sh" set "$plan" "$pr" "PR 作成済み" > /dev/null
    fi
  done <<EOF
$(state_rows "$plan")
EOF

  rows="$(state_rows "$plan")"
  if [ -z "$rows" ]; then
    echo "  「Phase の状態」の表がありません。/specramo:plan で作業計画書を更新してください"
    continue
  fi
  echo "| PR | Phase 名 | 状態 | 説明 |"
  echo "| --- | --- | --- | --- |"
  printf '%s\n' "$rows"
done
