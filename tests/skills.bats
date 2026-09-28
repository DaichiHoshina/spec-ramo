#!/usr/bin/env bats
# skills/: 全 skill の共通の形 (前提確認と雛形の解決) と、skill ごとの必須の手順を確かめる

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# init 以外の全 skill の SKILL.md を並べる
skills_except_init() {
  find "$ROOT/skills" -name SKILL.md ! -path "*/skills/init/*" | sort
}

@test "skills: init 以外の全 skill が冒頭で前提確認の script を呼ぶ" {
  run skills_except_init
  [ -n "$output" ]
  while IFS= read -r f; do
    grep -q 'scripts/require-config.sh' "$f" || { echo "前提確認が無い: $f"; return 1; }
  done <<< "$output"
}

@test "skills: 成果物を作る skill が雛形の解決の script を呼ぶ" {
  for s in prd design plan phase-design; do
    f="$ROOT/skills/$s/SKILL.md"
    [ -f "$f" ] || continue
    grep -qE "scripts/resolve-template\.sh\" $s( |\$)" "$f" || { echo "雛形の解決が無い: $f"; return 1; }
  done
}

@test "skills: 全 skill に description があり、利用者だけが呼ぶ skill になっている" {
  for f in "$ROOT"/skills/*/SKILL.md; do
    head -5 "$f" | grep -q '^description: ' || { echo "description が無い: $f"; return 1; }
    head -6 "$f" | grep -q '^disable-model-invocation: true' || { echo "利用者だけが呼ぶ設定が無い: $f"; return 1; }
  done
}

@test "skills: design は plugin の Design Doc 検査を呼ぶ" {
  grep -q 'CLAUDE_PLUGIN_ROOT}/scripts/dd-gate.sh' "$ROOT/skills/design/SKILL.md"
}

@test "skills: plan は Phase の状態の表を埋める手順と作業計画書検査を持つ" {
  grep -q '「Phase の状態」の表に、PR ごとの行を追加する' "$ROOT/skills/plan/SKILL.md"
  grep -q 'CLAUDE_PLUGIN_ROOT}/scripts/spec-gate.sh' "$ROOT/skills/plan/SKILL.md"
}

@test "skills: implement は着手時に状態を実装中にし、explain は説明列を記録する" {
  grep -q 'CLAUDE_PLUGIN_ROOT}/scripts/phase-state.sh" set <作業計画書の path> <n> 実装中' "$ROOT/skills/implement/SKILL.md"
  grep -q 'CLAUDE_PLUGIN_ROOT}/scripts/phase-state.sh" explained <作業計画書の path> <n>' "$ROOT/skills/explain/SKILL.md"
}

@test "skills: review は選択の script どおりに起動し、結果で状態を進める" {
  f="$ROOT/skills/review/SKILL.md"
  grep -q 'CLAUDE_PLUGIN_ROOT}/scripts/select-review-agents.sh' "$f"
  grep -q 'phase-state.sh" set <作業計画書の path> <n> レビュー済み' "$f"
  grep -q 'phase-state.sh" set <作業計画書の path> <n> 実装中' "$f"
  for a in review-design review-history review-rules review-language; do
    grep -q "specramo:$a" "$f"
    [ -f "$ROOT/agents/$a.md" ]
    grep -q "^name: $a$" "$ROOT/agents/$a.md"
  done
}

@test "agents: エージェント D は指針の書き方でなく動作への影響で重さを決め、慣習の違反を Warning にする" {
  f="$ROOT/agents/review-language.md"
  grep -q '放置したときに起きることで決める' "$f"
  grep -q '^- Warning: .*doc comment.*t.Parallel().*「必須」と書いていても Warning にする' "$f"
}

@test "skills: skill の本文が参照する同梱 file が実在する" {
  for f in "$ROOT"/skills/*/SKILL.md; do
    dir="$(dirname "$f")"
    for ref in $(grep -oE '`[a-z0-9-]+\.md`' "$f" | tr -d '`' | sort -u); do
      [ "$ref" = "SKILL.md" ] && continue
      case "$ref" in prd.md|design.md|plan.md|phase-design.md) continue ;; esac
      [ -f "$dir/$ref" ] || { echo "同梱 file が無い: $dir/$ref"; return 1; }
    done
  done
}
