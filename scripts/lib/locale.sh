#!/usr/bin/env bash
# 検査 script の文字数の判定 (grep -E の {0,120} など) を、利用者の locale によらず文字単位にする。
# C locale では日本語 1 文字が 3 byte として数えられ、同じ文書でも判定が変わる。source して使う

specramo_use_utf8_locale() {
  case "$(locale charmap 2>/dev/null)" in
    UTF-8|utf-8|utf8) return 0 ;;
  esac
  local available candidate
  available="$(locale -a 2>/dev/null)"
  for candidate in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
    if printf '%s\n' "$available" | grep -qx "$candidate"; then
      export LC_ALL="$candidate"
      return 0
    fi
  done
  return 1
}

specramo_use_utf8_locale || true
