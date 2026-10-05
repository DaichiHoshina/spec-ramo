#!/usr/bin/env bash
# spec 型 Design Doc の script 判定 gate。/specramo:design の品質 gate から呼ぶ。
# 判定 8 項目: (1) Implementation Surface の合計 1 行と表の行数の一致 (API と画面の表が無い変更は対象なしで PASS)
#             (2) 未確定 marker と「決める時点 = 作業計画書作成前 / DD レビュー」の残存
#             (3) 「受け入れ条件」 / 振る舞い / 決定事項 の識別子・HTTP status (warn)
#             (4) 決定事項の表 cell 長 (160 字超は読めない)
#             (5) 分岐のある受け入れ条件が 2 行以上あるのに振る舞いの図も番号付き手順も無い (warn)
#             (6) 受け入れ条件と振る舞いに曖昧な形容 (適切に / 堅牢 等) が残っている (warn)
#             (7) 既存の制約を削除・緩和・変更する Data Schema に、引き継ぎ先と確かめた箇所を記載した担い手の表がある
#             (8) 同じ Data Schema の先例が、現在の件数と撤回された件数で数えてある
# 出力: 1 行 1 判定 (PASS / FAIL / WARN)。FAIL が 1 つでもあれば exit 1
set -u
. "$(dirname "$0")/lib/locale.sh"

usage() { echo "usage: dd-gate.sh <design-doc.md>" >&2; exit 2; }
[ $# -eq 1 ] && [ -f "$1" ] || usage
DD="$1"
fail=0

report() { # $1=PASS|FAIL|WARN $2=item $3=detail
  printf '%s  %s  %s\n' "$1" "$2" "$3"
  [ "$1" = FAIL ] && fail=1
  return 0
}

# 節の本文を取り出す。$1 = 見出しの正規表現 (## か ### の後)。次の同レベル以上の見出しまで
section() {
  awk -v pat="$1" '
    /^#+ / {
      l = match($0, /[^#]/) - 1
      if (on && l <= lvl) { exit }
      if (!on && $0 ~ pat) { on = 1; lvl = l; next }
    }
    on { print }
  ' "$DD"
}

# 表の data 行 (header と区切り行を除く) を数える。stdin = 節本文。$1 = 表の 1 列目 header 名 (その表だけ数える)
table_rows() {
  awk -v hdr="$1" '
    /^\|/ {
      if (!in_tbl) { if (index($0, "| " hdr) == 1 || $0 ~ "^\\| *" hdr " *\\|") { in_tbl = 1; next } else { next } }
      if ($0 ~ /^\| *-+/) next
      n++; next
    }
    in_tbl && !/^\|/ { exit }
    END { print n + 0 }
  '
}

# 振る舞いの節の見出し。雛形は節名を英語にする指定で (templates/design.md 「外見」)、
# Section 6 の英語名は Proposed Design › Data Flow になる。日本語の節名だけで探すと、
# 規範に沿った DD でも節が 0 行になり、図があっても無いと判定する
BEHAVIOR_PAT='Behavior|振る舞い|Proposed Design'

# (1) 合計 1 行と表の行数
# API も画面も持たない変更 (CLI、batch、library、組み込み 等) では Backend API と Frontend の表を作らない。
# 表が無く合計にも数が無い項目は「対象なし」として PASS にし、表か合計の片方だけにあるときに食い違いとして扱う
api_body=$(section 'Backend API')
api_rows=$(printf '%s\n' "$api_body" | table_rows endpoint)
api_read=$(printf '%s\n' "$api_body" | grep -c '^| `[^|]*| *Read ')
api_write=$(printf '%s\n' "$api_body" | grep -c '^| `[^|]*| *Write ')
fe_rows=$(section 'Frontend' | table_rows 画面)
total_line=$(section '4\. Implementation Surface|Implementation Surface' | grep -m1 '^合計')
if [ -z "$total_line" ]; then
  if [ "$api_rows" -eq 0 ] && [ "$fe_rows" -eq 0 ]; then
    report PASS surface-total 'API と画面の表が無い (合計 1 行は任意)'
  else
    report FAIL surface-total '合計 1 行が無い'
  fi
else
  api_total=$(printf '%s' "$total_line" | grep -oE 'API[^0-9]*[0-9]+ 本' | grep -oE '[0-9]+' | head -1)
  read_total=$(printf '%s' "$total_line" | grep -oE 'Read [0-9]+' | head -1 | grep -oE '[0-9]+')
  write_total=$(printf '%s' "$total_line" | grep -oE 'Write [0-9]+' | head -1 | grep -oE '[0-9]+')
  screen_total=$(printf '%s' "$total_line" | grep -oE '画面 [0-9]+' | grep -oE '[0-9]+')
  if [ -z "$api_total" ] && [ "$api_rows" -eq 0 ]; then report PASS surface-api 'API の変更なし'
  elif [ "${api_total:-x}" = "$api_rows" ]; then report PASS surface-api "合計 ${api_total} 本 = 表 ${api_rows} 行"
  else report FAIL surface-api "合計 ${api_total:-?} 本 / 表 ${api_rows} 行"; fi
  if [ -z "$api_total" ] && [ "$api_rows" -eq 0 ]; then report PASS surface-rw 'API の変更なし'
  elif [ "${read_total:-x}" = "$api_read" ] && [ "${write_total:-x}" = "$api_write" ]; then report PASS surface-rw "Read ${api_read} / Write ${api_write}"
  else report FAIL surface-rw "合計 Read ${read_total:-?} / Write ${write_total:-?}、表 Read ${api_read} / Write ${api_write}"; fi
  if [ -z "$screen_total" ] && [ "$fe_rows" -eq 0 ]; then report PASS surface-screen '画面の変更なし'
  elif [ -z "$screen_total" ]; then report WARN surface-screen '合計に画面の数が無い'
  elif [ "$screen_total" = "$fe_rows" ]; then report PASS surface-screen "画面 ${fe_rows}"
  else report FAIL surface-screen "合計 画面 ${screen_total} / 表 ${fe_rows} 行"; fi
fi

# (2) 未確定の残存
pending=$(grep -c '【未確定' "$DD" || true)
if [ "$pending" -eq 0 ]; then report PASS open-marker '【未確定】marker 0'; else report FAIL open-marker "【未確定】marker ${pending} 件"; fi
oq_rows=$(section 'Open Questions|未確定事項' | grep '^| Q' | grep -v '| 確定' || true)
# 旧称「SPEC 作成前」で書かれた既存の DD も同じく判定する
oq_block=$(printf '%s\n' "$oq_rows" | grep -E '作業計画書作成前|SPEC 作成前|DD レビュー' | grep -vE '暫定決定|決定 [0-9]+|案 [A-Z]' | grep -c . || true)
if [ "$oq_block" -eq 0 ]; then report PASS open-deadline '決める時点 = 作業計画書作成前 / DD レビュー の未決 0'; else report FAIL open-deadline "作業計画書を止める未決 ${oq_block} 件"; fi

# (3) 識別子と HTTP status (warn)
spec_body=$( { section 'Acceptance Criteria|受け入れ条件'; section "$BEHAVIOR_PAT"; section 'Design Decisions|決定事項'; } )
ident=$(printf '%s\n' "$spec_body" | grep -cE '`[^`]*(/|[A-Za-z0-9_]\.[a-z]{2,5}\b)[^`]*`|\b(SELECT|INSERT|UPDATE|DELETE) \b' || true)
status=$(printf '%s\n' "$spec_body" | grep -cE '(^|[^0-9])(200|201|204|400|401|403|404|409|422|500)([^0-9]|$)' || true)
if [ "$ident" -eq 0 ]; then report PASS ident 'file path / SQL 0'; else report WARN ident "file path / SQL らしき行 ${ident}"; fi
if [ "$status" -eq 0 ]; then report PASS http-status 'HTTP status 0'; else report WARN http-status "HTTP status を含む行 ${status} (既存挙動の変更で明示した分は許容)"; fi

# (4) 決定事項の表 cell 長
# mawk の length は byte 数を返し、日本語 1 文字を 3 と数える。UTF-8 の継続 byte を除いてから数える
# macOS の awk は UTF-8 locale だと byte の範囲指定で消せないため、C locale で byte として扱わせる
long_cells=$(section 'Design Decisions|決定事項' | grep '^|' | grep -v '^| *-' | LC_ALL=C awk -F'|' '{ for (i = 2; i < NF; i++) { t = $i; gsub(/[\200-\277]/, "", t); if (length(t) > 160) c++ } } END { print c + 0 }')
if [ "$long_cells" -eq 0 ]; then report PASS decision-cell '160 字超の cell 0'; else report FAIL decision-cell "160 字超の cell ${long_cells} (bullet に戻す)"; fi

# (5) 振る舞いの図 (warn)
# 分岐語の検出は語彙に依存して取りこぼしと誤検出の両方が発生するので FAIL にしない。
# 閾値 2 は「1 つの分岐なら条件の表 1 行で追える」という template の線引きに合わせた
# (`templates/design.md` Section 6「条件の表 1 行では追えない場面に限る」)。
branch_rows=$(section 'Acceptance Criteria|受け入れ条件' \
  | grep '^|' | grep -v '^| *-' \
  | grep -cE '失敗|エラー|重複|同時|期限|キャンセル|取り消|再送|拒否|競合|上限|超え|できない' || true)
behavior_form=$(section "$BEHAVIOR_PAT" | grep -cE '^```mermaid|^[0-9]+\. ' || true)
if [ "$branch_rows" -lt 2 ]; then
  report PASS behavior-diagram "分岐のある条件 ${branch_rows} 行 (2 行未満は図の要否を判定しない)"
elif [ "$behavior_form" -gt 0 ]; then
  report PASS behavior-diagram "分岐のある条件 ${branch_rows} 行、振る舞いに図か番号付き手順あり"
else
  report WARN behavior-diagram "分岐のある条件 ${branch_rows} 行に対して振る舞いの図も番号付き手順も無い (sequence / state 図か番号付き手順を置く)"
fi

# (6) 曖昧な形容 (warn)
# 語彙に依存して取りこぼしと誤検出の両方が発生するので、behavior-diagram と同じく FAIL にしない。
# 「適切に処理する」の類は何を満たせば良いかの判断を実装者へ預けることになり、
# 受け入れ条件として機能しない (`skills/design/SKILL.md` 「Bad Design Doc」)。
VAGUE_PAT='適切に|正しく|高速|堅牢|直感的|柔軟|十分|スムーズ'
vague=$( { section 'Acceptance Criteria|受け入れ条件'; section "$BEHAVIOR_PAT"; } | grep -cE "$VAGUE_PAT" || true)
if [ "$vague" -eq 0 ]; then report PASS vague-adjective '曖昧な形容 0'; else report WARN vague-adjective "曖昧な形容を含む行 ${vague} (測れる条件に書き換える)"; fi

# (7)(8) 既存の制約を削除・緩和・変更する変更
# 制約 (UNIQUE / FK / NOT NULL / CHECK / 排他制御) を削除するか緩めると、その制約が守っていた不変条件を別の仕組みが引き継ぐ。
# 書き手は引き継ぎ先を名前だけ記載しやすく、その仕組みが実際に守るかを確かめないまま DD が PASS する。
# そこで担い手の表に「確かめた箇所」の列を必須にする (以前の列名「登録経路のロック」も受ける)。
# 先例を migration の追加数で数えると、後から撤回された形を先例と誤認するので、現在と撤回の 2 つの件数を必須にする。
# 起動は変更の種類で決める: 制約の削除・解除 / NULL の許可 / 型・長さ・キー範囲・参照動作の変更 / ENUM の値追加を記載した行があるか、担い手の表があるとき
# 「変える・広げる」は制約語と同じ行のときだけ数える (列や index の新設は制約を弱めないので起動しない)。
# 「追加」は ENUM だけに限る (UNIQUE や FK の追加は制約を強める側なので起動しない)。
schema_body=$(section 'Data Schema')
RELAX_PAT='(UNIQUE|FK|NOT NULL|CHECK|一意|外部キー|排他|制約).*(削除|緩め|緩和|外し|外す|やめ|廃止)'
RELAX_PAT+='|[Nn]ullable|NULL を許|NULL 許可'
RELAX_PAT+='|(UNIQUE|PRIMARY KEY|主キー|[^A-Za-z]PK|ENUM|CASCADE|SET NULL|VARCHAR|CHAR\(|長さ|桁数|外部キー|一意|CHECK).*(広げ|拡張|変え|変更)'
RELAX_PAT+='|ENUM.*追加'
OWNER_COL_PAT='(削除|緩和|緩め|変更)[^|]*後の担い手'
relax_lines=$(printf '%s\n' "$schema_body" | grep -E "$RELAX_PAT" || true)
has_owner_table=$(printf '%s\n' "$schema_body" | grep -E "^\\|.*${OWNER_COL_PAT}" || true)
if [ -z "$relax_lines" ] && [ -z "$has_owner_table" ]; then
  report PASS invariant-owner '制約の削除・緩和なし'
  report PASS invariant-precedent '制約の削除・緩和なし'
else
  owner_rows=$(printf '%s\n' "$schema_body" | awk -F'|' -v ocp="$OWNER_COL_PAT" '
    /^\|/ && !hdr { for (i = 2; i < NF; i++) { if ($i ~ ocp) oc = i; if ($i ~ /確かめた箇所|登録経路のロック/) ec = i }
                    if (oc) hdr = 1; next }
    hdr && /^\| *-/ { next }
    hdr && /^\|/ { n++; o = $oc; gsub(/[ \t]/, "", o); e = (ec ? $ec : ""); gsub(/[ \t]/, "", e)
                   if (o == "" || o == "-" || o == "—" || e == "" || e == "-" || e == "—") bad++; next }
    hdr && !/^\|/ { exit }
    END { printf "%d %d %d %d\n", hdr, ec, n, bad }')
  set -- $owner_rows
  if [ "$1" -eq 0 ]; then report FAIL invariant-owner '制約を削除するか緩めるのに、「削除・緩和した後の担い手」列のある担い手の表が無い'
  elif [ "$2" -eq 0 ]; then report FAIL invariant-owner '担い手の表に「確かめた箇所」列が無い (引き継ぐ仕組みが実際に守ることを確かめた code の位置)'
  elif [ "$3" -eq 0 ]; then report FAIL invariant-owner '担い手の表に行が無い'
  elif [ "$4" -gt 0 ]; then report FAIL invariant-owner "削除・緩和した後の担い手か確かめた箇所が空の行 ${4}"
  else report PASS invariant-owner "担い手 ${3} 行、全行に引き継ぎ先と確かめた箇所"; fi
  if printf '%s\n' "$schema_body" | grep '先例' | grep -E '現在 [0-9]+ 件' | grep -qE '撤回 [0-9]+ 件'; then
    report PASS invariant-precedent '先例に現在と撤回の件数あり'
  else
    report FAIL invariant-precedent '先例に「現在 n 件 / 撤回 m 件」が無い'
  fi
fi

exit $fail
