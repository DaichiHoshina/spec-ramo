#!/usr/bin/env bash
# 作業計画書 (Implementation Plan) の script 判定 gate。/specramo:plan の自己点検から呼ぶ。
# 判定 5 項目 (+ 参考 4 項目): (1) 各 PR 行に「想定変更行数: N」がある
#             (2) N が行数の上限 (設定 file の max_lines、無ければ 400) を超える PR があるときは「分割しない」理由が書かれている
#             (3) 各 PR の直下に branch 名の bullet がある (形は設定 file の branch_pattern に従う。未宣言なら形を検査しない)
#             (4) 完了条件と code block を除く全節に実装形 (method 名 / 先例の名指し / SQL / code 生成と検索の command / comment の位置) が混入していない
#                 (括弧を伴わない識別子は WARN の impl-form-bare で一覧にする)
#             (5) dead code first の雛形を採ったとき、既存挙動が変わる PR が 2 本以下である
#                 (雛形を採ったかは「- flag:」の行で見分ける。判定できないときは WARN)
#                 (対象を層と責務でなく file path で書いていると WARN の abstraction で一覧にする)
#                 (影響範囲に Change Map の節が無いか表でないと WARN の change-map)
#                 (品質基準の節が 2 行以上で埋まっていると WARN の prefill)
#                 (template の条件付き項目「該当する場合 / 必要に応じて」が消されずにあると WARN の template-leftover)
# 出力: 1 行 1 判定 (PASS / FAIL / WARN)。FAIL が 1 つでもあれば exit 1 (WARN は exit に影響しない)
set -u
. "$(dirname "$0")/lib/locale.sh"

usage() { echo "usage: spec-gate.sh <spec.md>" >&2; exit 2; }
[ $# -eq 1 ] && [ -f "$1" ] || usage
SPEC="$1"
fail=0
report() { printf '%s  %s  %s\n' "$1" "$2" "$3"; [ "$1" = FAIL ] && fail=1; return 0; }

# PR 見出しごとに、次の見出しまでの本文を 1 行にまとめて "見出し<TAB>本文" で返す。
# 見出しの深さは H3 と H4 の両方を受ける (repo の作業計画書 template が H4 で書く例がある)。
# 本文の終端は、その PR 見出しと同じか浅い見出しとする
pr_blocks() {
  awk '
    /^####? PR #/ { if (h != "") print h "\t" b; h = $0; lvl = index($0, " ") - 1; b = ""; next }
    /^#+ / && h != "" { if ((index($0, " ") - 1) <= lvl) { print h "\t" b; h = ""; b = ""; next } }
    h != "" { b = b " " $0 }
    END { if (h != "") print h "\t" b }
  ' "$SPEC"
}

# branch 名の形と行数の上限は導入先の設定 file から読む。設定 file か key が無ければ、
# branch 名は形を検査せずに有無だけを判定し、行数の上限は 400 にする
. "$(dirname "$0")/lib/config.sh"
config_file=$(specramo_config_path "$(dirname "$SPEC")") || config_file=""
branch_pattern=$(specramo_config_get "$config_file" branch_pattern 2>/dev/null) || branch_pattern=""
max_lines=$(specramo_config_get "$config_file" max_lines 2>/dev/null) || max_lines=""
case "$max_lines" in ''|*[!0-9]*) max_lines=400 ;; esac
if [ -n "$branch_pattern" ]; then
  # <issue> / <PR> / <n> は数字 (枝番の英字 1 文字を許す)、<a|b> は選択、その他の <word> は英数字
  branch_re=$(printf '%s' "$branch_pattern" | sed -E \
    -e 's/<(issue|PR|n|N)>/[0-9]+[a-z]?/g' \
    -e 's/<([a-z]+\|[a-z|]+)>/(\1)/g' \
    -e 's/<[^>]+>/[A-Za-z0-9._-]+/g')
  branch_label="$branch_pattern"
else
  branch_re='[^ ]+'
  branch_label='branch 名あり (branch_pattern 未宣言のため形は検査しない)'
fi

blocks=$(pr_blocks)
pr_count=$(printf '%s\n' "$blocks" | grep -c . || true)
if [ "$pr_count" -eq 0 ]; then report FAIL pr-rows 'PR 見出し (### PR #n または #### PR #n) が無い'; exit 1; fi

missing_est=0; over=0; missing_branch=0
while IFS=$'\t' read -r head body; do
  [ -z "$head" ] && continue
  est=$(printf '%s' "$body" | grep -oE '想定の?変更行数: *[0-9,]+' | head -1 | grep -oE '[0-9,]+' | tr -d ,)
  if [ -z "$est" ]; then missing_est=$((missing_est + 1)); elif [ "$est" -gt "$max_lines" ]; then over=$((over + 1)); fi
  printf '%s' "$body" | grep -qE "branch: *${branch_re}" || missing_branch=$((missing_branch + 1))
done <<EOF
$blocks
EOF

if [ "$missing_est" -eq 0 ]; then report PASS estimate "PR ${pr_count} 本すべてに想定変更行数"; else report FAIL estimate "想定変更行数の無い PR ${missing_est} 本"; fi
if [ "$over" -eq 0 ]; then report PASS over-limit "${max_lines} 行超の PR 0"; elif grep -q '分割しない' "$SPEC"; then report PASS over-limit "${max_lines} 行超 ${over} 本、分割しない理由あり"; else report FAIL over-limit "${max_lines} 行超 ${over} 本に分割しない理由が無い"; fi
# (5) 既存挙動が変わる PR の本数。見出しでなく PR 直下の bullet から数える。
# 「2 本以下」は dead code first の雛形を採ったときの上限なので
# (/specramo:plan)、雛形を採ったかどうかを PR 分割計画の「- flag:」の行で見分ける。
# 見出しの形 (既存挙動: の列) は雛形の有無に関係なく書かせるため、印として使えない
behavior_changed=$(printf '%s\n' "$blocks" | grep -cE '既存挙動: *変わる' || true)
behavior_rows=$(printf '%s\n' "$blocks" | grep -cE '既存挙動:' || true)
flag_line=$(grep -m1 -E '^- *flag: *[^ ]' "$SPEC" || true)
if printf '%s' "$flag_line" | grep -qE '^- *flag: *(使わない|使用しない|なし|無し)'; then
  printf '%s' "$flag_line" | grep -q '理由' && flag_mode=none || flag_mode=none-noreason
elif [ -n "$flag_line" ]; then
  flag_mode=used
elif grep -qE '既存挙動: *変わる *\([^)]*ON|flag *OFF|有効化 PR' "$SPEC"; then
  flag_mode=used
else
  flag_mode=unknown
fi
if [ "$behavior_rows" -eq 0 ]; then
  printf 'INFO  behavior  既存挙動の列なし (dead code first 雛形なら各 PR 行に「既存挙動:」を記載する)\n'
elif [ "$behavior_changed" -le 2 ]; then
  report PASS behavior "既存挙動が変わる PR ${behavior_changed} 本 (2 本以下)"
elif [ "$flag_mode" = used ]; then
  report FAIL behavior "既存挙動が変わる PR ${behavior_changed} 本、flag の置き場所を再検討する"
elif [ "$flag_mode" = none ]; then
  report PASS behavior "既存挙動が変わる PR ${behavior_changed} 本、flag を使わない理由あり"
elif [ "$flag_mode" = none-noreason ]; then
  printf 'WARN  behavior  既存挙動が変わる PR %s 本。flag を使わない理由が「- flag:」の行に無い\n' "$behavior_changed"
else
  printf 'WARN  behavior  既存挙動が変わる PR %s 本。dead code first の雛形を採ったか判定できない (PR 分割計画に「- flag: 使う / 使わない」の 1 行を記載する)\n' "$behavior_changed"
fi
if [ "$missing_branch" -eq 0 ]; then report PASS branch "PR ${pr_count} 本すべてに ${branch_label}"; else report FAIL branch "branch 名の無い PR ${missing_branch} 本 (期待する形: ${branch_label})"; fi

# source file と判定する拡張子。主要な言語を並べ、file:line と file path の検出に使う。
# ERE の選択は最長一致なので短い拡張子 (c / h / m) が長い拡張子 (cpp / hpp / mm) を切り詰めることは無い
SRC_EXT='go|ts|tsx|mts|cts|js|jsx|mjs|cjs|vue|svelte|py|rb|java|kt|kts|scala|groovy|swift|m|mm|c|h|cc|cpp|cxx|hpp|hh|cs|fs|rs|php|ex|exs|erl|hs|ml|clj|dart|lua|pl|r|jl|zig|nim|sh|bash|ps1|sql|proto|tf'
# code 生成と検索の command。make と npm 系は生成の target だけにする (test / lint はタスクの判定として記載される)
GEN_CMD='go generate|buf generate|make [A-Za-z0-9_:-]*gen|(npm|pnpm|yarn) run [A-Za-z0-9_:-]*gen|git grep|(^|[^A-Za-z0-9_-])rg [-A-Za-z0-9"'"'"']'

# (4) 実装形の混入。作業計画書は責務までを記述し、実装形は /specramo:phase-design が担当する (/specramo:plan)。
# 対象は完了条件と code block を除いた全節にする。Read/Write・実装への指針・タスクの 3 節だけを
# 判定すると、処理フロー・影響範囲・マージ順序に書かれた method 名と file:line を検出できない。
# 完了条件は定義が test 名と判定 command を要求しているので除く。code block は
# リリース手順の SQL と図が入るので除く
impl_sections=$(awk '
  /^```/ { fence = 1 - fence; next }
  fence { next }
  /^\*\*完了条件\*\*/ { skip = 1; lvl = 99; next }
  /^##?#?#?#?#? *完了条件/ { skip = 1; lvl = index($0, " ") - 1; next }
  /^##?#?#?#?#? / { if (skip && (index($0, " ") - 1) > lvl) next; skip = 0; print; next }
  /^\*\*/ { skip = 0 }
  !skip { print }
' "$SPEC")
impl_hits=$(printf '%s\n' "$impl_sections" | grep -nE '[A-Z][A-Za-z0-9_]*[a-z][A-Za-z0-9_]*\(|[A-Za-z0-9_/.-]+\.('"${SRC_EXT}"'):[0-9]+|'"${GEN_CMD}"'|TODO\(#' || true)
# SQL は Read/Write だけで数える。定義が SQL を名指しで禁じているのはこの項目で (/specramo:plan)、
# タスクの SQL は移行前のデータ確認のように判定 command として書かれることがある
rw_hits=$(awk '
  /^\*\*Read\/Write\*\*/ { on = 1; print; next }
  /^##?#?#?#?#? / { on = 0 }
  /^\*\*/ && !/^\*\*Read\/Write\*\*/ { on = 0 }
  on { print }
' "$SPEC" | grep -nE '(^|[^A-Za-z])(SELECT|INSERT|UPDATE|DELETE|JOIN|WHERE|LIMIT|IS NULL|ORDER BY|GROUP BY)([^A-Za-z]|$)' || true)
# 定義 (/specramo:plan の「実装への指針」) が名指しで対象外にしている 2 項目を検出する。
# どちらも Phase ごとに /specramo:phase-design が決めるので、着手前に全 Phase 分を作業計画書へ記載すると読めない量になる。
# 窓幅 120 は実測で決めた (40 では「comment に「…」と書く」の間に入る引用を取りこぼす)
precedent_hits=$(printf '%s\n' "$impl_sections" \
  | grep -nE '先例|の書き方に合わせ|にならう|に倣う|comment[^。]{0,120}(と書く|と記載|に置く|を置く)' || true)
impl_hits=$(printf '%s\n%s\n%s' "$impl_hits" "$rw_hits" "$precedent_hits" | grep -v '^$' || true)
impl_count=$(printf '%s' "$impl_hits" | grep -c . || true)
if [ "$impl_count" -eq 0 ]; then
  report PASS impl-form '実装形の混入 0'
else
  report FAIL impl-form "実装形 ${impl_count} 件 (method 名 / 先例の名指し / SQL / code 生成と検索の command / comment の位置)。/specramo:phase-design へ移す"
  printf '%s\n' "$impl_hits" | head -5 | sed 's/^/      /'
fi

# 括弧を伴わない識別子 (`BulkCreate` のような bare な method 名) は WARN にとどめる。
# 同じ書き方で型名や field 名も出力されるため、FAIL にすると誤検出を含む。
# test 名は完了条件とタスクの両方で正当に使うので対象外にする
bare_hits=$(printf '%s\n' "$impl_sections" \
  | grep -oE '`[A-Z][A-Za-z0-9_]*[a-z][A-Za-z0-9_]*`' | grep -vE '`Test' | sort -u || true)
bare_count=$(printf '%s' "$bare_hits" | grep -c . || true)
if [ "$bare_count" -gt 0 ]; then
  printf 'WARN  impl-form-bare  括弧なしの識別子 %s 種 (%s)。method 名なら /specramo:phase-design へ移す\n' \
    "$bare_count" "$(printf '%s' "$bare_hits" | tr '\n' ' ' | sed 's/ $//')"
fi

# 対象は層と責務の語で書く (/specramo:plan)。source file の path は /specramo:phase-design Step 2 が
# 実在を確かめてから記述するので、作業計画書に複製すると未検証の推測が残存する。
# その Phase で新規作成する file (migration / template) は名指しする必要があるため WARN にとどめる
path_hits=$(awk '
  /^####? *対象ファイル/ { on = 1; next }
  /^\*\*対象\*\*/ { on = 1; print; next }
  /^##?#?#?#?#? / { on = 0 }
  /^\*\*/ && !/^\*\*対象\*\*/ { on = 0 }
  on { print }
' "$SPEC" | grep -oE "[A-Za-z0-9_/.<>-]+\\.(${SRC_EXT}|html)\\b" | sort -u || true)
path_count=$(printf '%s' "$path_hits" | grep -c . || true)
if [ "$path_count" -gt 0 ]; then
  printf 'WARN  abstraction  対象に file path %s 件。層と責務の語で書き、path は /specramo:phase-design へ移す (新規作成する file は名指しのままでよい)\n' "$path_count"
  printf '%s\n' "$path_hits" | head -5 | sed 's/^/      /'
fi

# Change Map はシステム構造の中の変更境界を示す表で、対象層の列挙とは役割が違う (/specramo:plan)。
# 実行時の呼び出し経路と同じにする必要は無い (起動時の設定など、通過しないが変更が波及する箇所も行にする)。
# 変更しない層も行にして印の有無で区別するため、節の有無だけを判定して層の数は数えない。
# 層の語は repo ごとに違い、layers 未宣言の repo では経路の一部しか描けないので WARN にとどめる
change_map=$(awk '
  /^####? *Change Map/ { on = 1; next }
  /^##?#?#?#?#? / { if (on) exit }
  on { print }
' "$SPEC")
if [ -z "$change_map" ]; then
  report WARN change-map 'Change Map の節が無い。影響範囲に層と責務の表を置く (/specramo:plan)'
elif ! printf '%s\n' "$change_map" | grep -q '^| *層 *| *名前 *| *責務 *| *変更 *|'; then
  report WARN change-map 'Change Map の節に「| 層 | 名前 | 責務 | 変更 |」の表が無い (/specramo:plan)'
elif printf '%s\n' "$change_map" | grep '^|' | grep -q '★'; then
  report PASS change-map 'Change Map あり (表、変更層の印あり)'
else
  report WARN change-map 'Change Map の表に変更層の印 (★) が無い。印が無いと全層が変更対象に見える (/specramo:plan)'
fi

# 処理フローも Change Map と同じく、変わる手順に印 (★) と担当 PR を付ける (/specramo:plan)。
# 印が無いと、どの手順がどの PR で変わるかを本文の全 Phase から拾うことになる。節が無い作業計画書は対象外
flow=$(awk '
  /^## 処理フロー/ { on = 1; next }
  /^## / { if (on) exit }
  on { print }
' "$SPEC")
if [ -n "$flow" ]; then
  # 印の意味を説明する凡例の行は手順ではないので、番号付き手順の行だけを対象にする
  flow_marked=$(printf '%s\n' "$flow" | grep -E '^[0-9]+\. *★' || true)
  if [ -z "$flow_marked" ]; then
    report WARN flow-mark '処理フローの番号付き手順に変更する手順の印 (★) が無い。変わる手順に印と担当 PR を付ける (/specramo:plan)'
  elif printf '%s\n' "$flow_marked" | grep -qv 'PR #[0-9]'; then
    report WARN flow-mark '処理フローの ★ の手順に担当 PR (PR #N) が添えられていない行がある (/specramo:plan)'
  else
    report PASS flow-mark '処理フローの変更手順に印と担当 PR あり'
  fi
fi

# 品質基準は実装前には埋められないので、見出しと「実装中に記入」の 1 行だけにする (/specramo:plan Step 1)。
# 品質基準が 11 行ある作業計画書 (651 行) が全 PASS だった実例があるため、行数で検出する。
# 進捗記録 / 振り返り は実装中に正当な行が増え、--update 時の spec-gate で WARN になるので判定しない
prefill=$(awk '
  /^## +品質基準/ { on = 1; found = 1; next }
  /^## / { if (on) exit }
  on && NF { n++ }
  END { if (found) print n + 0 }
' "$SPEC")
if [ -n "$prefill" ]; then
  if [ "$prefill" -ge 2 ]; then
    report WARN prefill "実装前に埋められない節が埋まっている (品質基準: ${prefill} 行)。見出しと「実装中に記入」の 1 行にする (/specramo:plan Step 1)"
  else
    report PASS prefill '実装前に埋められない節は 1 行'
  fi
fi

leftover=$(grep -cE '^- \[ \].*(該当する場合|必要に応じて)' "$SPEC" || true)
if [ "$leftover" -ge 1 ]; then
  report WARN template-leftover "template の条件付き項目 ${leftover} 行 (該当する場合 / 必要に応じて)。該当しないなら消し、該当するなら条件を外して具体に記載する (/specramo:plan Step 1)"
fi

exit $fail
