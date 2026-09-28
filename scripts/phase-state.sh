#!/usr/bin/env bash
# 作業計画書の「Phase の状態」の表を読み書きする。implement / explain / review / status が共用する。
#
#   phase-state.sh get       <作業計画書> <PR 番号>            状態を表示する
#   phase-state.sh set       <作業計画書> <PR 番号> <新しい状態>  状態を書き換える (Design Doc 6.2 の遷移だけ許す)
#   phase-state.sh explained <作業計画書> <PR 番号> [日付]       説明列に日付を記録する (省略時は今日)
#
# PR 番号は 7 と #7 のどちらでもよい。
# 終了コード: 0 成功 / 1 引数の誤り / 2 表か行が無い / 3 遷移に無い書き換え
set -u

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

[ $# -ge 3 ] || usage
cmd="$1"
plan="$2"
pr="#${3#\#}"
[ -f "$plan" ] || { echo "作業計画書がありません: $plan"; exit 1; }

# 表の行を 1 行だけ取り出す。見つからなければ 2
find_row() {
  awk -v pr="$pr" '
    /^##+ / { in_sec = ($0 ~ /^##+ Phase の状態[ \t]*$/); next }
    in_sec && /^\|/ {
      n = split($0, c, "|")
      v = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v == pr) { print; found = 1; exit }
    }
    END { exit found ? 0 : 2 }
  ' "$plan"
}

# 列の値を trim して返す (1 = PR, 2 = Phase 名, 3 = 状態, 4 = 説明)
col() {
  printf '%s\n' "$1" | awk -v i="$2" -F'|' '{ v = $(i + 1); gsub(/^[ \t]+|[ \t]+$/, "", v); print v }'
}

# 表の対象行だけを差し替えて保存する。他の行と表の外は変えない
replace_row() {
  local new_row="$1" tmp
  tmp="$(mktemp "${plan}.XXXXXX")" || exit 1
  awk -v pr="$pr" -v row="$new_row" '
    /^##+ / { in_sec = ($0 ~ /^##+ Phase の状態[ \t]*$/) }
    in_sec && /^\|/ && !done {
      n = split($0, c, "|")
      v = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v == pr) { print row; done = 1; next }
    }
    { print }
  ' "$plan" > "$tmp" && mv "$tmp" "$plan"
}

allowed() {
  case "$1>$2" in
    "未着手>実装中" | "実装中>実装中" | "実装中>レビュー済み" | \
    "レビュー済み>実装中" | "レビュー済み>PR 作成済み") return 0 ;;
  esac
  return 1
}

if ! row="$(find_row)"; then
  echo "「Phase の状態」の表に $pr の行がありません: $plan"
  exit 2
fi
name="$(col "$row" 2)"
state="$(col "$row" 3)"
note="$(col "$row" 4)"

case "$cmd" in
  get)
    printf '%s\n' "$state"
    ;;
  set)
    [ $# -ge 4 ] || usage
    next="$4"
    if ! allowed "$state" "$next"; then
      echo "$state から $next には進めない"
      exit 3
    fi
    replace_row "| $pr | $name | $next | ${note:+$note }|"
    printf '%s\n' "$next"
    ;;
  explained)
    day="${4:-$(date '+%Y-%m-%d')}"
    replace_row "| $pr | $name | $state | $day |"
    printf '%s\n' "$day"
    ;;
  *)
    usage
    ;;
esac
