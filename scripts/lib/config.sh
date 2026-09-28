#!/usr/bin/env bash
# 導入先の設定 file (.specramo/config.yml) を読む。source して使う。
# 設定 file の場所: 環境変数 SPECRAMO_CONFIG > 引数の dir から上へたどって最初に見つかる .specramo/config.yml
# 書式は「key: value」の 1 行か、「key:」に続く「  - value」の list だけを扱う (YAML の他の書式は読まない)

# $1 = 探し始める dir。見つかった path を出す。無ければ何も出さずに 1 を返す
specramo_config_path() {
  if [ -n "${SPECRAMO_CONFIG:-}" ]; then
    [ -f "$SPECRAMO_CONFIG" ] && { printf '%s\n' "$SPECRAMO_CONFIG"; return 0; }
    return 1
  fi
  local dir
  dir="$(cd "${1:-.}" 2>/dev/null && pwd)" || return 1
  while :; do
    if [ -f "$dir/.specramo/config.yml" ]; then
      printf '%s\n' "$dir/.specramo/config.yml"
      return 0
    fi
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

# $1 = 設定 file の path、$2 = key。値を出す。list の key なら 1 行 1 要素で出す。無ければ 1 を返す
specramo_config_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  awk -v key="$key" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); gsub(/^["\x27]|["\x27]$/, "", s); return s }
    /^[^ \t#][^:]*:/ {
      if (inlist) exit
      k = $0; sub(/:.*/, "", k)
      if (k != key) next
      v = $0; sub(/^[^:]*:/, "", v); sub(/[ \t]+#.*$/, "", v); v = trim(v)
      if (v != "") { print v; found = 1; exit }
      inlist = 1; next
    }
    inlist && /^[ \t]+-[ \t]*/ { v = $0; sub(/^[ \t]+-[ \t]*/, "", v); v = trim(v); if (v != "") { print v; found = 1 }; next }
    inlist && /^[ \t]*($|#)/ { next }
    END { exit found ? 0 : 1 }
  ' "$file"
}
