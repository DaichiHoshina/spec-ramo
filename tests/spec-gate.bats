#!/usr/bin/env bats
# spec-gate.sh: 作業計画書の script 判定 3 項目。良い fixture で PASS し、条件を 1 つ壊すと該当項目だけ FAIL することを見る。

# GNU sed と BSD sed で -i の引数の形が違うので、どちらでも動く形にする
sedi() {
  if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi
}

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PROJECT_ROOT}/scripts/spec-gate.sh"
  SPEC="${BATS_TEST_TMPDIR}/spec.md"
  # branch 検査は設定 file の branch_pattern に従うので、case ごとに設定 file を固定する。
  # 宣言しないときの動きに任せると、cwd の repo の宣言の有無で判定が変わる
  CONF="${BATS_TEST_TMPDIR}/config.yml"
  printf 'branch_pattern: "<issue>-<be|fe>-<PR>"\n' > "$CONF"
  export SPECRAMO_CONFIG="$CONF"
  cat > "$SPEC" <<'EOF'
# 作業計画書: 例

## PR 分割計画

### PR #1: 物の table を追加する

- 依存: なし
- branch: 123-be-1

- 対象フェーズ: Phase 1 / 想定変更行数: 40 (根拠: 過去の migration 34)

### PR #2a: 物の取得 API

- 依存: PR #1
- branch: 123-be-2a

- 対象フェーズ: Phase 2a / 想定変更行数: 250 (根拠: #100 の 238)

### マージ順序と依存関係

- PR #1 → PR #2a

## 実装計画

### Phase 1: 物の table を追加する
EOF
}

@test "spec-gate: 整合した SPEC は全項目 PASS で exit 0" {
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  estimate  PR 2 本すべてに想定変更行数'
  printf '%s\n' "$output" | grep -q '^PASS  branch  PR 2 本'
}

@test "spec-gate: 「想定の変更行数」と書いた PR も estimate が PASS" {
  sedi 's/想定変更行数: /想定の変更行数: /g' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  estimate  PR 2 本すべてに想定変更行数'
}

@test "spec-gate: 想定変更行数の無い PR があると estimate が FAIL" {
  sedi 's/想定変更行数: 250 (根拠: #100 の 238)/根拠だけ/' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  estimate  想定変更行数の無い PR 1 本'
}

@test "spec-gate: 400 行超の PR に分割しない理由が無いと over-limit が FAIL、理由があれば PASS" {
  sedi 's/想定変更行数: 250/想定変更行数: 560/' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  over-limit  400 行超 1 本に分割しない理由が無い'
  printf '\n- 2a は merge 後にできることが 1 つなので分割しない\n' >> "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  over-limit  400 行超 1 本、分割しない理由あり'
}

@test "spec-gate: 設定 file の max_lines を 300 にすると、350 行の PR が over-limit で FAIL" {
  printf 'max_lines: 300\n' >> "$CONF"
  sedi 's/想定変更行数: 250/想定変更行数: 350/' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  over-limit  300 行超 1 本に分割しない理由が無い'
}

@test "spec-gate: max_lines が無い設定 file では上限が 400 になる" {
  sedi 's/想定変更行数: 250/想定変更行数: 350/' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  over-limit  400 行超の PR 0'
}

@test "spec-gate: 環境変数が無いときは、検査対象の file の dir から上へ探した設定 file を使う" {
  unset SPECRAMO_CONFIG
  mkdir -p "${BATS_TEST_TMPDIR}/repo/.specramo" "${BATS_TEST_TMPDIR}/repo/specs/x"
  printf 'max_lines: 300\n' > "${BATS_TEST_TMPDIR}/repo/.specramo/config.yml"
  cp "$SPEC" "${BATS_TEST_TMPDIR}/repo/specs/x/plan.md"
  sedi 's/想定変更行数: 250/想定変更行数: 350/' "${BATS_TEST_TMPDIR}/repo/specs/x/plan.md"
  run bash "$SCRIPT" "${BATS_TEST_TMPDIR}/repo/specs/x/plan.md"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  over-limit  300 行超 1 本'
}

@test "spec-gate: node が PATH に無くても全判定が表示され、終了コードが変わらない" {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  for c in bash awk grep sed sort tr head cat dirname; do
    p="$(command -v "$c")" && ln -sf "$p" "${BATS_TEST_TMPDIR}/bin/$c"
  done
  PATH="${BATS_TEST_TMPDIR}/bin" run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  estimate'
  printf '%s\n' "$output" | grep -q '^PASS  impl-form'
}

@test "spec-gate: branch 名が規則 <issue>-<be|fe>-<n> に合わない PR があると branch が FAIL" {
  sedi 's/branch: 123-be-2a/branch: feature-things-api/' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  branch  branch 名の無い PR 1 本'
}

@test "spec-gate: branch_pattern が未宣言の repo では branch 名の形を検査しない" {
  export SPECRAMO_CONFIG="${BATS_TEST_TMPDIR}/absent.yml"
  sedi 's/branch: 123-be-2a/branch: feature-things-api/' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  branch  PR 2 本すべてに branch 名あり'
}

@test "spec-gate: branch_pattern が未宣言でも branch 名が無い PR は FAIL" {
  export SPECRAMO_CONFIG="${BATS_TEST_TMPDIR}/absent.yml"
  sedi '/^- branch: 123-be-2a$/d' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  branch  branch 名の無い PR 1 本'
}

@test "spec-gate: 宣言された branch_pattern が別の形なら、その形で判定する" {
  printf 'branch_pattern: "<type>/<slug>"\n' > "$CONF"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  branch  branch 名の無い PR 2 本'
  sedi -e's|branch: 123-be-1|branch: feat/things-table|' -e 's|branch: 123-be-2a|branch: feat/things-api|' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  branch  PR 2 本すべてに <type>/<slug>'
}

@test "spec-gate: PR 見出しが H4 の SPEC も H3 と同じ判定になる" {
  sedi 's/^### PR #/#### PR #/' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  estimate  PR 2 本すべてに想定変更行数'
  printf '%s\n' "$output" | grep -q '^PASS  branch  PR 2 本'
}

@test "spec-gate: H4 の PR 見出しでも本文は次の同じ深さの見出しまでで区切る" {
  sedi 's/^### PR #/#### PR #/' "$SPEC"
  # 1 本目の PR に H5 の小見出しを足しても、2 本目の想定変更行数が 1 本目に混ざらない
  sedi 's|^- 対象フェーズ: Phase 1 / 想定変更行数: 40 (根拠: 過去の migration 34)|##### タスク\n- 対象フェーズ: Phase 1|' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  estimate  想定変更行数の無い PR 1 本'
}

@test "spec-gate: 既存挙動の判定も H4 の PR 見出しで数える" {
  cat >> "$SPEC" <<'EOF2'

### PR #3: 配線

- 依存: PR #2a
- branch: 123-be-3
- 既存挙動: 変わる (flag ON のとき)

- 対象フェーズ: Phase 3 / 想定変更行数: 30 (根拠: 配線のみ)

### PR #4: 有効化

- 依存: PR #3
- branch: 123-be-4
- 既存挙動: 変わる

- 対象フェーズ: Phase 4 / 想定変更行数: 1 (根拠: 定数 1 行)

### PR #5: 画面

- 依存: PR #4
- branch: 123-fe-5
- 既存挙動: 変わる

- 対象フェーズ: Phase 5 / 想定変更行数: 120 (根拠: 画面 1 つ)
EOF2
  sedi 's/^### PR #/#### PR #/' "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  behavior  既存挙動が変わる PR 3 本'
}

@test "spec-gate: PR 見出しが無い file は pr-rows が FAIL" {
  printf '# 空\n' > "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  pr-rows'
}

@test "spec-gate: 既存挙動の列が無い SPEC は INFO だけで FAIL しない" {
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^INFO  behavior'
}

@test "spec-gate: 既存挙動が変わる PR が 3 本以上なら behavior が FAIL" {
  cat >> "$SPEC" <<'EOF2'

### PR #3: 配線

- 依存: PR #2a
- branch: 123-be-3
- 既存挙動: 変わる (flag ON のとき)

- 対象フェーズ: Phase 3 / 想定変更行数: 30 (根拠: 配線のみ)

### PR #4: 有効化

- 依存: PR #3
- branch: 123-be-4
- 既存挙動: 変わる

- 対象フェーズ: Phase 4 / 想定変更行数: 1 (根拠: 定数 1 行)

### PR #5: 画面

- 依存: PR #4
- branch: 123-fe-5
- 既存挙動: 変わる

- 対象フェーズ: Phase 5 / 想定変更行数: 120 (根拠: 画面 1 つ)
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  behavior  既存挙動が変わる PR 3 本'
}

@test "spec-gate: 既存挙動が変わる PR が 2 本以下なら behavior が PASS" {
  cat >> "$SPEC" <<'EOF2'

### PR #3: 配線

- 依存: PR #2a
- branch: 123-be-3
- 既存挙動: 変わらない

- 対象フェーズ: Phase 3 / 想定変更行数: 30 (根拠: 配線のみ)

### PR #4: 有効化

- 依存: PR #3
- branch: 123-be-4
- 既存挙動: 変わる

- 対象フェーズ: Phase 4 / 想定変更行数: 1 (根拠: 定数 1 行)
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  behavior  既存挙動が変わる PR 1 本'
}

@test "spec-gate: タスクに method 名があると impl-form が FAIL" {
  cat >> "$SPEC" <<'EOF2'

#### タスク

- [ ] `NewOrderDeliveryOptionWithExecutor(ex gorp.SqlExecutor)` を追加する
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form  実装形 1 件'
}

@test "spec-gate: 実装への指針に先例 file:line があると impl-form が FAIL" {
  cat >> "$SPEC" <<'EOF2'

**実装への指針**: 先例は `pkg/writer/payment_card_log.go:42` にある
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form'
}

@test "spec-gate: タスクの go generate と git grep を実装形として数える" {
  cat >> "$SPEC" <<'EOF2'

#### タスク

- [ ] `go generate` で mock を再生成する
- [ ] `git grep -n DeleteByIDs` が 0 件であることを確かめる
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form  実装形 2 件'
}

@test "spec-gate: タスクの make gen と buf generate を実装形として数える" {
  cat >> "$SPEC" <<'EOF2'

#### タスク

- [ ] `make gen` で mock を再生成する
- [ ] `buf generate` で client を再生成する
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form  実装形 2 件'
}

@test "spec-gate: タスクの make test と npm test は impl-form に数えない" {
  cat >> "$SPEC" <<'EOF2'

#### タスク

- [ ] `make test` が通ることを確かめる
- [ ] `npm test` が通ることを確かめる
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^PASS  impl-form  実装形の混入 0'
}

@test "spec-gate: 責務だけのタスクと完了条件の test command は impl-form を FAIL させない" {
  cat >> "$SPEC" <<'EOF2'

**Read/Write**: 配送オプションの選択の無効化 (新規)。取り消しの 3 経路から呼ぶ

**完了条件**:

- [ ] `go test -tags=serial -p 1 ./pkg/writer/ -run ShipmentImpl_Request` が通る

#### タスク

- [ ] 取り消しで配送オプションの選択を無効化し、行を残す
- [ ] 無効行を残留と判定しないようにする
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^PASS  impl-form  実装形の混入 0'
}

@test "spec-gate: SQL の COUNT を method 名と誤検出しない" {
  cat >> "$SPEC" <<'EOF2'

#### タスク

- [ ] 事前に `GROUP BY order_id HAVING COUNT(*) > 1` が 0 件であることを確かめる
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^PASS  impl-form  実装形の混入 0'
}

@test "spec-gate: 括弧なしの method 名は WARN にとどめ FAIL にしない" {
  cat >> "$SPEC" <<'EOF2'

#### タスク

- [ ] `DeleteByOrderIDs` の呼び出しを削除する
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^PASS  impl-form  実装形の混入 0'
  printf '%s\n' "$output" | grep -q '^WARN  impl-form-bare  括弧なしの識別子 1 種'
}

@test "spec-gate: 括弧なしの識別子のうち test 名は WARN に数えない" {
  cat >> "$SPEC" <<'EOF2'

#### タスク

- [ ] `TestOrderDeliveryOption_Create` を削除する
EOF2
  run bash "$SCRIPT" "$SPEC"
  ! printf '%s\n' "$output" | grep -q '^WARN  impl-form-bare'
}

@test "spec-gate: 対象に file path があると abstraction が WARN" {
  cat >> "$SPEC" <<'EOF2'

**対象**: `pkg/reader/order_delivery_option.go`: 単件 / 複数の取得
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^WARN  abstraction  対象に file path 1 件'
}

@test "spec-gate: Go と TypeScript 以外の言語の file path も abstraction が WARN" {
  cat >> "$SPEC" <<'EOF2'

**対象**: `src/order/reader.rs` と `app/models/order.rb` と `lib/Order.java` と `cli/main.py`: 単件取得
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^WARN  abstraction  対象に file path 4 件'
}

@test "spec-gate: 拡張子の前方一致 (.config を .c と読む) を file path にしない" {
  cat >> "$SPEC" <<'EOF2'

**対象**: 設定 (`app.config`): 読み込みの既定値
EOF2
  run bash "$SCRIPT" "$SPEC"
  ! printf '%s\n' "$output" | grep -q '^WARN  abstraction'
}

@test "spec-gate: 実装への指針に Rust の先例 file:line があると impl-form が FAIL" {
  cat >> "$SPEC" <<'EOF2'

**実装への指針**: 形は `src/writer/payment.rs:42` と同じにする
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form'
}

@test "spec-gate: 層と責務で書いた対象は abstraction を WARN にしない" {
  cat >> "$SPEC" <<'EOF2'

**対象**: Reader (配送オプションの選択): 単件取得と複数取得を、有効な行だけに限定する
EOF2
  run bash "$SCRIPT" "$SPEC"
  ! printf '%s\n' "$output" | grep -q '^WARN  abstraction'
}

@test "spec-gate: 完了条件の判定 command の package path は abstraction に数えない" {
  cat >> "$SPEC" <<'EOF2'

**対象**: Reader (配送オプションの選択): 有効な行だけを返す

**完了条件**:

- [ ] `go test -tags=serial -p 1 ./pkg/reader/ -run OrderDeliveryOption` が通る
EOF2
  run bash "$SCRIPT" "$SPEC"
  ! printf '%s\n' "$output" | grep -q '^WARN  abstraction'
}

@test "spec-gate: 完了条件に書いた test file の path は abstraction に数えない" {
  cat >> "$SPEC" <<'EOF2'

**対象**: Reader (配送オプションの選択): 有効な行だけを返す

**完了条件**:

- [ ] `pkg/reader/order_delivery_option_test.go` に無効行を除く case を追加する
EOF2
  run bash "$SCRIPT" "$SPEC"
  ! printf '%s\n' "$output" | grep -q '^WARN  abstraction'
}

# 「変わる 2 本以下」は dead code first の雛形を採ったときの上限なので (/sdd-plan Step 3)、
# 雛形を採ったかどうかで判定が分かれる。以下 4 件はその分岐を見る
three_changed_prs() {
  cat >> "$SPEC" <<'EOF2'

### PR #3: 取り消しで行を残す

- 依存: PR #2a
- branch: 123-be-3
- 既存挙動: 変わる

- 対象フェーズ: Phase 3 / 想定変更行数: 30 (根拠: 取り消し経路のみ)

### PR #4: 登録を同じ transaction にする

- 依存: PR #3
- branch: 123-be-4
- 既存挙動: 変わる

- 対象フェーズ: Phase 4 / 想定変更行数: 60 (根拠: 登録経路 2 か所)

### PR #5: 管理画面に列を足す

- 依存: PR #4
- branch: 123-fe-5
- 既存挙動: 変わる

- 対象フェーズ: Phase 5 / 想定変更行数: 120 (根拠: 画面 1 つ)
EOF2
}

@test "spec-gate: flag を使わない理由があれば変わる PR 3 本でも behavior が PASS" {
  three_changed_prs
  printf -- '- flag: 使わない (理由: 切り替えの対象が行の意味そのもので、両方の経路を残す期間を作れない)\n' >> "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  behavior  既存挙動が変わる PR 3 本、flag を使わない理由あり'
}

@test "spec-gate: flag の宣言が無いと変わる PR 3 本は FAIL でなく WARN" {
  three_changed_prs
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  behavior  既存挙動が変わる PR 3 本。dead code first の雛形を採ったか判定できない'
  ! printf '%s\n' "$output" | grep -q '^FAIL  behavior'
}

@test "spec-gate: flag を使う宣言があれば変わる PR 3 本は behavior が FAIL" {
  three_changed_prs
  printf -- '- flag: delivery_option_soft_delete (配線 PR で OFF、有効化 PR で ON)\n' >> "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  behavior  既存挙動が変わる PR 3 本、flag の置き場所を再検討する'
}

@test "spec-gate: flag を使わない宣言に理由が無いと behavior が WARN" {
  three_changed_prs
  printf -- '- flag: 使わない\n' >> "$SPEC"
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  behavior  既存挙動が変わる PR 3 本。flag を使わない理由が'
}

@test "spec-gate: Read/Write に SQL があると impl-form が FAIL" {
  cat >> "$SPEC" <<'EOF2'

**Read/Write**: 発送内の商品一覧 (LEFT JOIN の条件に `deleted_at IS NULL` を加える)
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form'
}

@test "spec-gate: 対象を目的語で書いた責務は impl-form に数えない" {
  cat >> "$SPEC" <<'EOF2'

**Read/Write**: 取り消された配送オプションの選択を除いた単件取得と一覧取得、発送内の商品一覧 (取り消された選択を含めない)
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^PASS  impl-form'
}

@test "spec-gate: 完了条件の DELETE 文言は impl-form に数えない" {
  cat >> "$SPEC" <<'EOF2'

**完了条件**:

- [ ] DELETE を発行しないことを確かめる test が通る
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^PASS  impl-form'
}

@test "spec-gate: 図の幅の判定は同梱しないので、diagram-width の行を表示しない" {
  run bash "$SCRIPT" "$SPEC"
  ! printf '%s\n' "$output" | grep -q 'diagram-width'
}

@test "spec-gate: 実装への指針の先例の名指しを impl-form が FAIL にする" {
  cat >> "$SPEC" <<'EOF2'

**実装への指針**: 先例は `migrations/349_.up.sql` の同名の列の追加
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form'
}

@test "spec-gate: 先例の番号を指した 書き方に合わせ を impl-form が FAIL にする" {
  cat >> "$SPEC" <<'EOF2'

**実装への指針**: comment は 712 / 742 の書き方に合わせ、比喩語を使わない
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form'
}

@test "spec-gate: タスクの comment の位置の指示を impl-form が FAIL にする" {
  cat >> "$SPEC" <<'EOF2'

#### タスク

- [ ] down の先頭 comment に「事前に `GROUP BY order_id HAVING COUNT(*) > 1` が 0 件であることを確認する」と書く
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form'
}

@test "spec-gate: comment を書かない repo 規範の引用は impl-form に数えない" {
  cat >> "$SPEC" <<'EOF2'

**実装への指針**: `code-comment.md` (comment は既定で記載しない、what の言い換えを追加しない)
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^PASS  impl-form'
}

# 判定の対象は完了条件と code block を除く全節にする (2026-09-18)。3 節だけを見ていた間、
# 処理フロー・影響範囲・マージ順序へ実装形が流れ込んでも PASS だった
@test "spec-gate: 処理フローの method 名を impl-form が FAIL にする" {
  cat >> "$SPEC" <<'EOF2'

## 処理フロー

### A. 配送依頼が成功するとき

1. 同じ transaction 内で `NewOrderDeliveryOptionWithExecutor(tx)` を構築して登録する
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form'
}

@test "spec-gate: 影響範囲の根拠に書いた file:line を impl-form が FAIL にする" {
  cat >> "$SPEC" <<'EOF2'

### 既存への影響

| 層 | 影響 | 根拠 |
|---|---|---|
| 管理画面 | 列が 1 つ増える | 呼び出し元は `server/admin/users.go:1547` の 1 か所だけ |
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^FAIL  impl-form'
}

@test "spec-gate: code block のリリース手順の SQL は impl-form に数えない" {
  cat >> "$SPEC" <<'EOF2'

### マージ順序と依存関係

補完の DML を 1 回実行する。

```sql
UPDATE order_delivery_options s
SET s.shipment_id = 1
WHERE s.shipment_id IS NULL;
```
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^PASS  impl-form  実装形の混入 0'
}

@test "spec-gate: 節見出しの完了条件に書いた判定 command は impl-form に数えない" {
  cat >> "$SPEC" <<'EOF2'

## 完了条件

### 品質要件

- [ ] `git grep -n 'DeleteByOrderIDs' -- '*.go'` が 0 件
EOF2
  run bash "$SCRIPT" "$SPEC"
  printf '%s\n' "$output" | grep -q '^PASS  impl-form  実装形の混入 0'
}

@test "spec-gate: Change Map の節が無いと change-map が WARN (exit には影響しない)" {
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  change-map  Change Map の節が無い'
}

@test "spec-gate: 変更層に印のある表の Change Map は change-map が PASS" {
  cat >> "$SPEC" <<'EOF2'

## 影響範囲

### Change Map

| 層 | 名前 | 責務 | 変更 |
|---|---|---|---|
| Usecase | 配送依頼 | 入力を検証する | ★ PR #1 |
| Framework & Driver | API | 依頼を受け付ける | 変更なし |
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  change-map  Change Map あり (表、変更層の印あり)'
}

@test "spec-gate: Change Map の表に変更層の印が無いと change-map が WARN" {
  cat >> "$SPEC" <<'EOF2'

## 影響範囲

### Change Map

| 層 | 名前 | 責務 | 変更 |
|---|---|---|---|
| Framework & Driver | API | 依頼を受け付ける | 変更なし |
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  change-map  Change Map の表に変更層の印'
}

@test "spec-gate: Change Map が mermaid の図だと change-map が WARN" {
  cat >> "$SPEC" <<'EOF2'

## 影響範囲

### Change Map

```mermaid
flowchart TB
  API[API] --> UC[Usecase ★]
```
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  change-map  Change Map の節に「| 層 | 名前 | 責務 | 変更 |」の表が無い'
}

@test "spec-gate: 処理フローに印 (★) と担当 PR があると flow-mark が PASS" {
  cat >> "$SPEC" <<'EOF2'

## 処理フロー

1. 配送オプションを選択する
2. ★ 配送依頼を作る — PR #3 で transaction の内側へ移動する
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  flow-mark'
}

@test "spec-gate: 処理フローに印が無いと flow-mark が WARN" {
  cat >> "$SPEC" <<'EOF2'

## 処理フロー

1. 配送オプションを選択する
2. 配送依頼を作る
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  flow-mark  処理フローの番号付き手順に変更する手順の印'
}

@test "spec-gate: 処理フローの ★ に担当 PR が無いと flow-mark が WARN" {
  cat >> "$SPEC" <<'EOF2'

## 処理フロー

1. ★ 配送依頼を作る
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  flow-mark  処理フローの ★'
}

@test "spec-gate: 処理フローの凡例に ★ があっても手順に PR があれば flow-mark が PASS" {
  cat >> "$SPEC" <<'EOF2'

## 処理フロー

印 (★) の付いた手順だけが今回の変更で挙動が変わる。

1. 配送オプションを選択する
2. ★ 配送依頼を作る — PR #3 で transaction の内側へ移動する
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  flow-mark'
}

@test "spec-gate: 処理フローの凡例だけに ★ があり手順に印が無いと flow-mark が WARN" {
  cat >> "$SPEC" <<'EOF2'

## 処理フロー

印 (★) の付いた手順だけが今回の変更で挙動が変わる。

1. 配送オプションを選択する
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^WARN  flow-mark  処理フローの番号付き手順'
}

@test "spec-gate: 品質基準が「実装中に記入」の 1 行だけなら prefill が PASS" {
  cat >> "$SPEC" <<'EOF2'

## 品質基準

実装中に記入
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^PASS  prefill'
}

@test "spec-gate: 品質基準に checkbox が 3 行あると prefill が WARN で exit 0" {
  cat >> "$SPEC" <<'EOF2'

## 品質基準

- [ ] test が通る
- [ ] lint が 0 件
- [ ] 型 error が 0 件
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep '^WARN  prefill' | grep -q '品質基準: 3 行'
}

@test "spec-gate: 品質基準の節が無ければ prefill の行を出力しない" {
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  ! printf '%s\n' "$output" | grep -q 'prefill'
}

@test "spec-gate: template の条件付き項目があると template-leftover が WARN" {
  cat >> "$SPEC" <<'EOF2'

- [ ] パフォーマンス基準を満たす（該当する場合）
EOF2
  run bash "$SCRIPT" "$SPEC"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep '^WARN  template-leftover' | grep -q '1 行'
}
