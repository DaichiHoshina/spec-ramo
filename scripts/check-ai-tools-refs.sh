#!/usr/bin/env bash
# plugin に同梱する file に、ai-tools と作者の手元にしか無い path が混ざっていないかを数える。
# 1 件でも見つかれば該当行を出して exit 1。引数が無ければ repo root の同梱 dir を検査する。
# 出力: 1 行 1 判定 (PASS / FAIL)
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
if [ $# -gt 0 ]; then
  targets=("$@")
else
  targets=()
  for d in skills agents scripts templates guidelines; do
    [ -d "$root/$d" ] && targets+=("$root/$d")
  done
fi

# 検出する語: 作者の設定 dir、ai-tools の repo 名、非公開設定の dir 名
pattern='~/\.claude/|\$HOME/\.claude|\$\{HOME\}/\.claude|ai-tools|references-private'
self="$root/scripts/check-ai-tools-refs.sh"

hits=""
if [ ${#targets[@]} -gt 0 ]; then
  hits=$(grep -rnE "$pattern" "${targets[@]}" 2>/dev/null | grep -v "^${self}:" || true)
fi

if [ -z "$hits" ]; then
  echo "PASS  ai-tools-refs  0 件"
  exit 0
fi
count=$(printf '%s\n' "$hits" | grep -c .)
echo "FAIL  ai-tools-refs  ${count} 件"
printf '%s\n' "$hits" | sed 's/^/      /'
exit 1
