#!/usr/bin/env bash
# Phase 詳細設計を script で判定する。/specramo:phase-design の Step 4 から呼ぶ。
# 保存データの意味が変わる変更 (論理削除への切り替え / 状態の値の追加 / 列の意味の変更 など) では、
# 条件の追加が必要な query が別の package や管理画面にもある。調べる手順を文章で記載するだけでは
# 実行されないことがあったので、件数の一致と query ごとの判断の行数で、調べたことを確かめる。
#
# 判定 3 項目:
#   (1) declaration: 「意味が変わる table: <table 名 (カンマ区切り)> / なし」の行がある
#   (2) table-readers: 宣言した table ごとに「table を読む query」の節へ「table: <table 名>」と「合計 n 件」があり、
#       n が table-readers.sh で改めて数えた件数と一致する
#   (3) table-readers-decision: 宣言した table ごとに、query の件数以上の判断の行がある
#       「扱い: 変更する (根拠)」/「扱い: 変更しない (根拠)」を数える。根拠の括弧が無い行は数えない。
#       以前の形「複数行の扱い: 最新 1 件だけを対象にする / 全行を対象にする / 1 件以下が保証される」も数える
# 出力: 1 行 1 判定 (PASS / FAIL)。FAIL が 1 つでもあれば exit 1
set -u
. "$(dirname "$0")/lib/locale.sh"

usage() { echo "usage: phase-gate.sh <phase-design.md>" >&2; exit 2; }
[ $# -eq 1 ] && [ -f "$1" ] || usage
DOC="$1"
fail=0
report() { printf '%s  %s  %s\n' "$1" "$2" "$3"; [ "$1" = FAIL ] && fail=1; return 0; }

decl=$(grep -m1 -E '^[-* ]*意味が変わる table:' "$DOC" | sed -E 's/^[-* ]*意味が変わる table:[[:space:]]*//')
if ! grep -qE '^[-* ]*意味が変わる table:' "$DOC"; then
  report FAIL declaration '「意味が変わる table: <table 名> / なし」の行が無い (保存データの行や状態の意味が変わるかを宣言する)'
  exit 1
fi
# 全角の読点と括弧は C locale で 1 文字として扱えないので、tr や [] を使わず sed の選択で置き換える
tables=$(printf '%s\n' "$decl" | sed -E 's/`//g; s/(,|、)/ /g' | tr -s ' \t' '\n\n' | grep -v '^$' || true)
if [ -z "$tables" ] || [ "$tables" = "なし" ]; then
  report PASS declaration '意味が変わる table なし'
  exit 0
fi
for t in $tables; do
  case "$t" in *[!A-Za-z0-9_]*)
    report FAIL declaration "「${t}」は table 名として読めない (英数字と _ の名前をカンマ区切りで記載する)"
    exit 1 ;;
  esac
done
report PASS declaration "意味が変わる table: $(printf '%s ' $tables)"

body=$(awk '/^#+ / { on = ($0 ~ /table を読む query/); next } on { print }' "$DOC")
if [ -z "$body" ]; then
  report FAIL table-readers '「table を読む query」の節が無い (scripts/table-readers.sh の出力を貼る)'
  exit 1
fi

# 設計書を git 管理外の dir に置く運用があるので、そのときは cwd の repo で数える
repo=$(git -C "$(dirname "$DOC")" rev-parse --show-toplevel 2>/dev/null) \
  || repo=$(git rev-parse --show-toplevel 2>/dev/null) || repo=""

# 「table: <名前>」の行から次の「table:」の行までを、その table の記載とみなす。名前は完全一致で比べる
block() {
  printf '%s\n' "$body" | awk -v t="$1" '
    /^table: / { name = $0; sub(/^table: *`?/, "", name); sub(/[`[:space:]].*$/, "", name); on = (name == t); next }
    on { print }'
}

for t in $tables; do
  if ! printf '%s\n' "$body" | grep -qE "^table: *\`?${t}(\`|[[:space:]]|$)"; then
    report FAIL table-readers "${t}: 節に「table: ${t}」の行が無い"
    continue
  fi
  b=$(block "$t")
  written=$(printf '%s\n' "$b" | grep -oE '合計 [0-9]+ 件' | head -1 | grep -oE '[0-9]+' || true)
  if [ -z "$written" ]; then
    report FAIL table-readers "${t}: 「合計 n 件」が無い"
    continue
  fi
  if [ -z "$repo" ]; then
    report FAIL table-readers "${t}: 設計書の dir も cwd も git の repo の外にあるため件数を確かめられない (対象 repo の root で実行する)"
    continue
  fi
  actual=$(bash "$(dirname "$0")/table-readers.sh" "$repo" "$t" | tail -1 | grep -oE '[0-9]+')
  if [ "$written" != "$actual" ]; then
    report FAIL table-readers "${t}: 節は ${written} 件、改めて数えると ${actual} 件"
    continue
  fi
  report PASS table-readers "${t}: 合計 ${actual} 件 (改めて数えた件数と一致)"
  # 件数が合っていても、query ごとに扱いを決めたかは分からない。全件を列挙するだけでは、
  # 条件の追加が必要な query の判断が書かれず、その条件が実装に反映されない
  decided=$(printf '%s\n' "$b" | grep -cE '^[-* ]*(扱い: *(変更する|変更しない) *(\(|（).+(\)|）)|複数行の扱い: *(最新 1 件だけを対象にする|全行を対象にする|1 件以下が保証される))' || true)
  if [ "$decided" -ge "$actual" ]; then
    report PASS table-readers-decision "${t}: 扱いを ${decided} 件記載 (query ${actual} 件)"
  else
    report FAIL table-readers-decision "${t}: 扱いが ${decided} 件、query は ${actual} 件 (query ごとに「- 扱い: 変更する (根拠)」か「- 扱い: 変更しない (根拠)」を記載する)"
  fi
done

exit $fail
