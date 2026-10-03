#!/usr/bin/env bash
# /specramo:review が起動するエージェントを決める。1 行 1 エージェントで、tab 区切りの
#   <A|B|C|D> <TAB> run  <TAB> <エージェントに渡す値>
#   <A|B|C|D> <TAB> skip <TAB> <省いた理由>
# を表示する。渡す値は、B が指摘データの dir、C が規約 file (空白区切り)、D が開発指針の
# file (空白区切り。guidelines/languages/extensions.tsv で差分の拡張子に対応する指針。無ければ空) になる。C の規約の path が存在しない
# ときは 1 path 1 行で
#   warn <TAB> C <TAB> <警告>
# を表示する。skill はこの表示どおりに起動する。
# 引数: $1 = 設定 file を探し始める dir (省略時は current dir)、$2 以降 = 差分の file 名
# 環境変数: SPECRAMO_REVIEW_DATA_DIR (B の指摘データの場所。未設定なら ~/.config/specramo/review-data)
set -u

here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib/config.sh"
plugin_root="$(dirname "$here")"

start_dir="${1:-.}"
[ $# -gt 0 ] && shift

config="$(specramo_config_path "$start_dir")" || {
  echo "設定 file (.specramo/config.yml) がありません。/specramo:init を実行してください"
  exit 2
}
repo_root="$(dirname "$(dirname "$config")")"
tab="$(printf '\t')"

# A 設計書との比較: 常に起動する
printf 'A%srun%s\n' "$tab" "$tab"

# B 過去の指摘: 指摘データの場所に file が 1 つ以上あるときだけ起動する
data_dir="${SPECRAMO_REVIEW_DATA_DIR:-$HOME/.config/specramo/review-data}"
if [ -d "$data_dir" ] && [ -n "$(find "$data_dir" -type f 2>/dev/null | head -1)" ]; then
  printf 'B%srun%s%s\n' "$tab" "$tab" "$data_dir"
else
  printf 'B%sskip%s指摘データが無いため B を省いた (%s)\n' "$tab" "$tab" "$data_dir"
fi

# C repo の規約: 設定 file の rules のうち存在する path。未記入なら .claude/rules/ の file
found=""
if rules="$(specramo_config_get "$config" rules)"; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ -e "$repo_root/$p" ]; then
      found="${found:+$found }$p"
    else
      printf 'warn%sC%s規約の path が存在しない: %s\n' "$tab" "$tab" "$p"
    fi
  done <<EOF
$rules
EOF
  reason="設定 file の rules に存在する path が無いため C を省いた"
else
  if [ -d "$repo_root/.claude/rules" ]; then
    found="$(cd "$repo_root" && find .claude/rules -type f -name '*.md' | sort | tr '\n' ' ' | sed 's/ $//')"
  fi
  reason="規約 (rules の設定と .claude/rules/) が無いため C を省いた"
fi
if [ -n "$found" ]; then
  printf 'C%srun%s%s\n' "$tab" "$tab" "$found"
else
  printf 'C%sskip%s%s\n' "$tab" "$tab" "$reason"
fi

# D 言語の開発指針: 常に起動し、差分に含まれる拡張子に対応する開発指針だけを渡す。
# 拡張子と指針の対応は guidelines/languages/extensions.tsv が正本で、言語を足すときは表に行を追加する
lang_dir="$plugin_root/guidelines/languages"
exts=""
for f in "$@"; do
  base="${f##*/}"
  case "$base" in *.*) exts="${exts}${base##*.}${tab}" ;; esac
done
guides=""
if [ -n "$exts" ] && [ -f "$lang_dir/extensions.tsv" ]; then
  # 差分に現れた拡張子の行を表の順に取り、同じ指針を 2 度渡さない
  for g in $(awk -F'\t' -v exts="$exts" '
    BEGIN { n = split(exts, e, "\t"); for (i = 1; i <= n; i++) if (e[i] != "") want[e[i]] = 1 }
    /^#/ || NF < 2 { next }
    ($1 in want) { m = split($2, gs, " "); for (j = 1; j <= m; j++) if (!(gs[j] in seen)) { seen[gs[j]] = 1; print gs[j] } }
  ' "$lang_dir/extensions.tsv"); do
    [ -f "$lang_dir/$g" ] && guides="${guides:+$guides }$lang_dir/$g"
  done
fi
printf 'D%srun%s%s\n' "$tab" "$tab" "$guides"
