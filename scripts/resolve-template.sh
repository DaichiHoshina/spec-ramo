#!/usr/bin/env bash
# 使う雛形の path を表示する。導入先の .specramo/templates/<名前>.md があればそれを、
# 無ければ plugin の templates/<名前>.md を使う。
# 引数: 雛形の名前 (prd / design / plan / phase-design)、探し始める dir (省略時は current dir)
# 終了コード: 0 = 表示した / 2 = 知らない名前
set -u

. "$(dirname "$0")/lib/config.sh"
plugin_root="$(cd "$(dirname "$0")/.." && pwd)"

name="${1:-}"
case "$name" in
  prd|design|plan|phase-design) ;;
  *) echo "知らない雛形の名前です: ${name} (prd / design / plan / phase-design のどれか)" >&2; exit 2 ;;
esac

if config="$(specramo_config_path "${2:-.}")"; then
  local_template="$(dirname "$config")/templates/${name}.md"
  if [ -f "$local_template" ]; then
    printf '%s\n' "$local_template"
    exit 0
  fi
fi
printf '%s\n' "$plugin_root/templates/${name}.md"
