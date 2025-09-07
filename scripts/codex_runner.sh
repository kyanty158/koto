#!/usr/bin/env bash
set -euo pipefail

# Minimal auto-runner for Codex-like loop
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

while true; do
  if [[ ! -f .codex/tasks.yaml ]]; then
    echo "[runner] .codex/tasks.yaml not found" >&2
    exit 1
  fi

  TASK_ID=$(awk '/^- id:/{print $3; exit}' .codex/tasks.yaml | tr -d '"')
  if [[ -z "${TASK_ID:-}" ]]; then
    echo "[runner] タスクがありません。60秒待機…"
    sleep 60
    continue
  fi

  # Move the picked task from todo -> doing if yq is available (idempotent-ish)
  if command -v yq >/dev/null 2>&1; then
    yq -i '.doing += [ .todo[0] ] | .todo |= del(.[0])' .codex/tasks.yaml || true
  fi

  TASK_BLOCK=$(awk -v id="$TASK_ID" '
    $0 ~ "- id: " id {flag=1}
    flag {print}
    /^  - id: / && $0 !~ id && flag {exit}
  ' .codex/tasks.yaml)

  DIFF=$(git status --porcelain; git diff --patch --stat | tail -n +1 | sed -e 's/^/    /')

  read -r -d '' PAYLOAD <<'EOF'
あなたは最高水準のFlutter+Firebaseアプリ開発エージェントです。
- 目的: リポジトリの次タスクを安全に実装して前進させる。
- 厳守: .codex/guardrails.md、プロジェクト規約、既存アーキに準拠。
- 出力: 「変更方針 → 変更ファイルと差分 → 実行/テスト手順」を明記。
- 完了条件: タスクの done_when を満たし、CIがgreenになること。

【現在タスク】
EOF

  PROMPT=$(printf "%s\n%s\n\n【リポジトリ状況（要約）】\n%s\n\n【恒常プロンプト】\n%s\n" \
      "$PAYLOAD" "$TASK_BLOCK" "$DIFF" "$(cat .codex/prompt.md 2>/dev/null || true)")

  if ! command -v codex >/dev/null 2>&1; then
    echo "[runner] codex CLI が見つかりません。インストールしてください。" >&2
    exit 1
  fi

  RESPONSE=$(codex "$PROMPT") || true

  mkdir -p .codex/logs
  TS=$(date +"%Y%m%d_%H%M%S")
  echo "$RESPONSE" > ".codex/logs/${TS}_${TASK_ID}.md"

  (flutter pub get || true)
  (dart format -o write . || true)
  (flutter analyze || true)
  (flutter test || true)

  if ! git diff --quiet; then
    git add -A
    git commit -m "feat(${TASK_ID}): auto-impl by codex-runner"
  fi

  # Mark doing -> done if yq is available
  if command -v yq >/dev/null 2>&1; then
    yq -i '.done += .doing | .doing = []' .codex/tasks.yaml || true
  fi

  echo "[runner] ${TASK_ID} を処理完了。次へ。"
  sleep 5
done
