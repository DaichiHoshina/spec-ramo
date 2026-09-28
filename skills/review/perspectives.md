# 汎用 12 観点と判定の基準

`/specramo:review` のエージェント A (`specramo:review-design`) が、Phase 固有の観点と合わせて当てる汎用の観点。

## 観点

| Perspective | Description |
|---|---|
| **architecture** | Layer knowledge boundaries (what each layer may and must not know), dependency direction, where a decision belongs, the same rule implemented in two layers, CQRS lane separation |
| **quality** | Language/FW best practice, local idioms, code smell, performance, type safety |
| **readability** | Naming, cognitive complexity, consistency |
| **logging** | Log level appropriateness, structured logs |
| **security** | Authn/authz, injection, secrets, tenant/data isolation, unsafe logging |
| **docs** | Doc quality, comments that diverge from the code |
| **test-coverage** | Test adequacy and quality |
| **writing** | Human-facing doc quality |
| **root-cause** | Permanent fix vs workaround, recurrence patterns |
| **silent-failure** | Error swallowing, empty catch |
| **type-design** | Type-encoded invariants, avoid enum abuse |
| **db-concurrency** | Deadlock / gap lock / FOR UPDATE + INSERT / external I/O in TX / missing retry |

**regression-guard (常時適用)**: 今は壊れていない箇所への劣化を検出する観点。観点の選択によらず、下の「Regression Guard」の表を当てる。

## 変更 file の種類と当てる観点

基本の観点は `quality` / `architecture` / `root-cause` / `security` の 4 つで、変更 file の種類に応じて次のように増減する。

| Condition | Perspectives |
|---|---|
| All files are `.md` / `.json` / `.yaml` / `.yml` / `.txt` / `.toml` | `docs` / `writing` / `readability` / `root-cause` だけ |
| Test file (`*_test.*`, `*.spec.*`) | 基本の 4 つに `docs` + `test-coverage` を加える |
| Logic change (non-test) | 基本の 4 つに `test-coverage` + `silent-failure` を加える |
| Type def change (`*.d.ts`, `types/*`, struct / interface added) | 基本の 4 つに `type-design` を加える |
| SQL / ORM change | 基本の 4 つに `db-concurrency` を加える |
| Mixed / uncertain | 12 観点全部 |

## 重大度の付け方

候補ごとに 0-100 で確信度を付け、**80 以上を Critical、50-79 を Warning、25 未満を破棄**にする。候補を採る前に次の 4 点を確かめる。

| Check | Pass condition |
|---|---|
| 根拠 | Anchored to diff / code / docs / tests / tool output |
| Scope | Tied to the Phase scope, a code contract, or changed behavior; no invented requirement |
| Actionability | The author can fix it in this change; severity matches real impact |
| Style | Backed by a documented rule (not taste); a reasonable engineer calls it a defect, not another valid alternative |

「こうした方がきれい」「X を検討してもよい」のように欠陥の無い候補は破棄する。指摘 0 件は正しい結果で、指摘を作らない。

## 判定の基準

### Architecture

| Severity | Item | Description |
|---|---|---|
| Critical | Layer violation | Domain referencing Infrastructure, UseCase with framework-specific logic |
| Critical | Dependency inversion broken | Domain depends on Repository impl, missing DI |
| Critical | Bypass access | Controller → DB direct, skipping UseCase |
| Critical | Business logic in wrong layer | Logic in Controller / Infrastructure |
| Warning | Over-abstraction | Unnecessary interfaces / layers |
| Warning | Fat Service | Multiple responsibilities in one Service |
| Warning | Ubiquitous language mismatch | Naming diverges from domain terminology or from the word the repo already uses |

### Quality

| Severity | Item | Description |
|---|---|---|
| Critical | Type safety | `any`, unvalidated `as`, `interface{}` |
| Critical | Performance | N+1, memory leaks |
| Warning | Code smell | Functions >100 lines, magic numbers |
| Warning | Unused code in diff | PR includes unused interface methods / functions |
| Warning | HTTP status mismatch | 400 for a server issue, BadRequest for not found |

### Readability

| Severity | Item | Description |
|---|---|---|
| Critical | Misleading names | Name ≠ actual behavior |
| Critical | Cryptic code | Intent unclear, complex one-liners |
| Warning | Naming quality | Breaks the Naming Criteria / Naming Shape in `${CLAUDE_PLUGIN_ROOT}/skills/implement/code-quality.md` |
| Warning | Cognitive complexity | Deep nesting (3+ levels), long conditionals |
| Warning | Consistency | Inconsistent naming within the project (count the precedents before flagging; the majority wins) |
| Warning | Over-engineering (YAGNI) | Unused abstractions, helpers called once |

### Security

| Severity | Item | Description |
|---|---|---|
| Critical | `Injection` | SQL (string concat), XSS (innerHTML), command injection |
| Critical | Auth broken | Plaintext passwords, session leaks |
| Critical | Secret leaks | password / token / secret in logs |

### Docs and Testing

| Severity | Item | Description |
|---|---|---|
| Critical | False comments | Comments diverge from implementation |
| Critical | No real assertion | `expect(user).toBeDefined()` only |
| Critical | Over-mocking | All mocks, no actual behavior verified |
| Warning | Test isolation | Shared state, execution order dependency |
| Warning | Coverage gaps | Missing error / boundary case tests |

### Regression Guard (差分外への劣化)

diff 内で完結しないため、grep と呼び出し元の探索を伴う。差分だけで判定できる項目から先に当てる。

| Severity | Item | Description |
|---|---|---|
| Critical | Paired asymmetry | 対になる処理の片側だけを変更している。合計と明細、追加と削除、encode と decode が典型 |
| Critical | Unit / scale mixing | 秒とミリ秒、税込と税抜、UTC と local を同じ変数で扱う |
| Critical | Shared default blast radius | 共有の初期値の引数や共通定数の変更が、diff に現れない既存の呼び出し元の挙動を変える |
| Warning | Sibling divergence | 同じ処理が複数箇所にあり、変更が片方にしか入っていない (同名 symbol を grep で数える) |
| Warning | Reason not recorded | magic number / timeout / retry 回数の根拠が diff にも comment にも無い。指摘の前に `git log -S <値>` で履歴側の根拠を確かめる |
| Warning | Test shares the assumption | test が実装と同じ前提 (単位 / TZ / 境界) で組まれ、誤りを検出できない |

### Root Cause

| Severity | Item | Description |
|---|---|---|
| Critical | Symptomatic fix | Hiding with null checks / try-catch / conditionals |
| Critical | Error suppression | Ignoring errors (empty catch, `_ = err`) |
| Warning | Local-only fix | Fixing 1 spot but the pattern exists in 3+ places |

### Logging

| Severity | Item | Description |
|---|---|---|
| Critical | Secret in logs | password / token / Cookie / PII / full request body |
| Critical | Missing error context | No error object in logs |
| Warning | Wrong log level | warn / error for success, info for errors |
| Warning | Over-logging | Logs in loops |

## 出力の形

```
### Critical
- [security] SQL injection (src/api/user.ts:120) — 根拠: 入力を文字列連結して query を組み立てている。修正: placeholder を使う
### Warning
- [quality] 独自の sort callback が不要 (pkg/sort.go:15) — 根拠: 要素型は ordered。修正: slices.Sort を使う
```

指摘 0 件なら `確認できた指摘はありません。` とする。確信度の数値と破棄した件数は出力しない。
