#!/usr/bin/env bash
# table を FROM と JOIN で読む箇所を、repo の git 管理下の file から全件数える。/specramo:phase-design の調査から呼ぶ。
# test と migration は除く (行の意味が変わったときに条件の追加を検討する対象は、本番で実行される query のため)。
# 出力: 1 行 1 箇所 (file:line: 本文)。末尾の行は「合計 n 件」。引数が足りなければ exit 2
set -u
. "$(dirname "$0")/lib/locale.sh"

usage() { echo "usage: table-readers.sh <repo-dir> <table>" >&2; exit 2; }
[ $# -eq 2 ] && [ -d "$1" ] || usage
repo="$1"
table="$2"
case "$table" in ''|*[!A-Za-z0-9_]*) usage ;; esac

hits=$(git -C "$repo" grep -n -I -i -E "(from|join)[[:space:]]+\`?${table}\`?([^A-Za-z0-9_]|$)" -- . \
  ':!*_test.*' ':!*.spec.*' ':!*.test.*' ':!**/migrations/**' ':!migrations/**' ':!.specramo/**' 2>/dev/null || true)

if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  count=$(printf '%s\n' "$hits" | grep -c .)
else
  count=0
fi
echo "合計 ${count} 件"
