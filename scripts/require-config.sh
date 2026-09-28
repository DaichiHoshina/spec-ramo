#!/usr/bin/env bash
# init 以外の全コマンドが最初に呼ぶ前提確認。設定 file が見つかれば path を表示して 0、
# 見つからなければ init の案内を表示して 2 を返す。
# 引数: 探し始める dir (省略時は current dir)
set -u

. "$(dirname "$0")/lib/config.sh"

if path="$(specramo_config_path "${1:-.}")"; then
  printf '%s\n' "$path"
  exit 0
fi
echo "設定 file (.specramo/config.yml) がありません。/specramo:init を実行してください"
exit 2
