#!/usr/bin/env bash
set -euo pipefail

MAX_ITERATIONS="${1:-10}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="${PROMPT_FILE:-$SCRIPT_DIR/prompt.md}"
PRD_FILE="${PRD_FILE:-$SCRIPT_DIR/prd.json}"

# Default agent command; override via RALPH_AGENT_CMD.
# Use codex exec for non-interactive (headless) runs.
AGENT_CMD=(codex exec --dangerously-bypass-approvals-and-sandbox)
if [[ -n "${RALPH_AGENT_CMD:-}" ]]; then
  # shellcheck disable=SC2206
  AGENT_CMD=(${RALPH_AGENT_CMD})
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -n "${RALPH_AGENT_CMD:-}" ]]; then
    echo "Not a git repo. Initialize with: git init" >&2
    echo "Or include --skip-git-repo-check in RALPH_AGENT_CMD." >&2
    exit 1
  fi
  if [[ "${RALPH_SKIP_GIT_CHECK:-}" == "1" ]]; then
    AGENT_CMD+=(--skip-git-repo-check)
  else
    echo "Not a git repo. Initialize with: git init" >&2
    echo "Or run with RALPH_SKIP_GIT_CHECK=1 to bypass the Git check." >&2
    exit 1
  fi
fi

echo "Starting Ralph"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo "=== Iteration $i ==="

  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Missing prompt file: $PROMPT_FILE" >&2
    exit 1
  fi
  if [[ ! -f "$PRD_FILE" ]]; then
    echo "Missing prd file: $PRD_FILE" >&2
    exit 1
  fi

  # codex exec reads prompt content from stdin when passed "-" as the prompt arg.
  OUTPUT=$("${AGENT_CMD[@]}" - < "$PROMPT_FILE" 2>&1 \
    | tee /dev/stderr) || true

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    HAS_PENDING=1
    if command -v jq >/dev/null 2>&1; then
      if jq -e '.userStories[] | select(.passes == false)' "$PRD_FILE" >/dev/null 2>&1; then
        HAS_PENDING=1
      else
        HAS_PENDING=0
      fi
    fi

    if [[ "$HAS_PENDING" -eq 0 ]]; then
      echo "Done!"
      exit 0
    else
      echo "Ignoring COMPLETE because pending stories remain in $PRD_FILE" >&2
    fi
  fi

  sleep 2
done

echo "Max iterations reached"
exit 1
