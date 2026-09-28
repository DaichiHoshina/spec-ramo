#!/usr/bin/env bash
# Phase 詳細設計を script で判定する。/specramo:phase-design の Step 4 から呼ぶ。
# 判定 1 項目: table の行の意味が変わる Phase (論理削除 / deleted_at) に「table を読む query」の節があり、
#              節に記載した「合計 n 件」が、table-readers.sh で改めて数えた件数と一致する
# 行の意味が変わると、条件の追加が必要な query が別の package や管理画面にもある。
# 調べる手順を文章で記載するだけでは実行されないことがあったので、件数の一致で調べたことを確かめる。
# 出力: 1 行 1 判定 (PASS / FAIL)。FAIL が 1 つでもあれば exit 1
set -u
. "$(dirname "$0")/lib/locale.sh"

usage() { echo "usage: phase-gate.sh <phase-design.md>" >&2; exit 2; }
[ $# -eq 1 ] && [ -f "$1" ] || usage
DOC="$1"
fail=0
report() { printf '%s  %s  %s\n' "$1" "$2" "$3"; [ "$1" = FAIL ] && fail=1; return 0; }

if ! grep -qE 'deleted_at|論理削除' "$DOC"; then
  report PASS table-readers '行の意味が変わる変更なし'
  exit 0
fi

body=$(awk '/^#+ / { on = ($0 ~ /table を読む query/); next } on { print }' "$DOC")
if [ -z "$body" ]; then
  report FAIL table-readers '「table を読む query」の節が無い (scripts/table-readers.sh の出力を貼る)'
  exit 1
fi

repo=$(git -C "$(dirname "$DOC")" rev-parse --show-toplevel 2>/dev/null) || repo=""
tables=$(printf '%s\n' "$body" | grep -oE '^table: *`?[A-Za-z0-9_]+' | sed -E 's/^table: *`?//')
if [ -z "$tables" ]; then
  report FAIL table-readers '節に「table: <table 名>」の行が無い'
  exit 1
fi

for t in $tables; do
  written=$(printf '%s\n' "$body" | awk -v t="$t" '
    /^table: / { on = (index($0, t) > 0); next }
    on && /合計 [0-9]+ 件/ { match($0, /合計 [0-9]+ 件/); print substr($0, RSTART, RLENGTH); exit }' | grep -oE '[0-9]+')
  if [ -z "$written" ]; then
    report FAIL table-readers "${t}: 「合計 n 件」が無い"
    continue
  fi
  if [ -z "$repo" ]; then
    report FAIL table-readers "${t}: git の repo の外にあるため件数を確かめられない"
    continue
  fi
  actual=$(bash "$(dirname "$0")/table-readers.sh" "$repo" "$t" | tail -1 | grep -oE '[0-9]+')
  if [ "$written" = "$actual" ]; then
    report PASS table-readers "${t}: 合計 ${actual} 件 (改めて数えた件数と一致)"
  else
    report FAIL table-readers "${t}: 節は ${written} 件、改めて数えると ${actual} 件"
  fi
done

exit $fail
