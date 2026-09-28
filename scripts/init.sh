#!/usr/bin/env bash
# 導入先に Spec Ramo の設定 file と成果物の置き場所を作る。/specramo:init から呼ぶ。
# どちらも、すでにあれば作らない (既存の file は変更しない)。
# 引数: 対象の dir (省略時は git の repo root、repo でなければ current dir)
# 出力: 1 行 1 file で「作った: <path>」か「作らなかった (すでにある): <path>」。終了コードは常に 0
set -u

plugin_root="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -ge 1 ]; then
  target="$1"
else
  target="$(git rev-parse --show-toplevel 2>/dev/null)" || target="$(pwd)"
fi
target="$(cd "$target" && pwd)" || { echo "対象の dir がありません: $1" >&2; exit 2; }

config="$target/.specramo/config.yml"
specs="$target/.specramo/specs"

if [ -e "$config" ]; then
  echo "作らなかった (すでにある): .specramo/config.yml"
else
  mkdir -p "$(dirname "$config")"
  cp "$plugin_root/templates/config.yml" "$config"
  echo "作った: .specramo/config.yml"
fi

if [ -e "$specs" ]; then
  echo "作らなかった (すでにある): .specramo/specs/"
else
  mkdir -p "$specs"
  echo "作った: .specramo/specs/"
fi
