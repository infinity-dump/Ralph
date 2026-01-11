#!/usr/bin/env bash
set -euo pipefail

MAX_ITERATIONS="${1:-10}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="${PROMPT_FILE:-$SCRIPT_DIR/prompt.md}"
PRD_FILE="${PRD_FILE:-$SCRIPT_DIR/prd.json}"

select_story() {
  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  jq -c '
    def normalized_status:
      if .passes == true then "completed"
      elif .status then .status
      else "pending"
      end;
    def normalized_priority:
      if (.priority | type) == "number" then .priority
      elif (.priority | type) == "string" then
        if .priority == "high" then 1
        elif .priority == "medium" then 5
        elif .priority == "low" then 9
        else 5 end
      else 5 end
      | if . < 1 then 1 elif . > 10 then 10 else . end;
    def dependencies_list:
      if (.dependencies | type) == "array" then .dependencies else [] end;

    . as $root
    | ($root.userStories // []) as $stories
    | ($stories | map(select((. | normalized_status) == "completed") | .id)) as $completed
    | $stories
    | to_entries
    | map(.value as $story
        | {
            story: $story,
            index: .key,
            status: ($story | normalized_status),
            priority: ($story | normalized_priority),
            dependencies: ($story | dependencies_list)
          })
    | map(select(.status != "completed" and .status != "blocked"))
    | map(select(
        (.dependencies | length == 0)
        or all(.dependencies[]; $completed | index(.) != null)
      ))
    | sort_by(.priority, .index)
    | .[0] // empty
  ' "$PRD_FILE" 2>/dev/null || true
}

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

  STORY_CONTEXT=""
  STORY_SELECTION="$(select_story)"
  if [[ -n "$STORY_SELECTION" ]]; then
    STORY_JSON="$(jq -c '.story' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_ID="$(jq -r '.story.id // empty' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_TITLE="$(jq -r '.story.title // empty' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_PRIORITY="$(jq -r '.priority // empty' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_STATUS="$(jq -r '.status // empty' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_DEPS="$(jq -c '.dependencies // []' <<<"$STORY_SELECTION" 2>/dev/null || true)"

    if [[ -n "$STORY_JSON" ]]; then
      echo "Selected story: ${STORY_ID:-unknown} - ${STORY_TITLE:-untitled} (priority ${STORY_PRIORITY:-n/a})"
      STORY_CONTEXT=$(
        cat <<EOF
# Ralph Story Selection
Selected story: ${STORY_ID:-unknown} - ${STORY_TITLE:-untitled}
Priority: ${STORY_PRIORITY:-n/a}
Status: ${STORY_STATUS:-n/a}
Dependencies: ${STORY_DEPS:-[]}

Story JSON:
${STORY_JSON:-}

EOF
      )
    fi
  fi

  # codex exec reads prompt content from stdin when passed "-" as the prompt arg.
  if [[ -n "$STORY_CONTEXT" ]]; then
    OUTPUT=$(
      {
        printf "%s" "$STORY_CONTEXT"
        cat "$PROMPT_FILE"
      } | "${AGENT_CMD[@]}" - 2>&1 | tee /dev/stderr
    ) || true
  else
    OUTPUT=$("${AGENT_CMD[@]}" - < "$PROMPT_FILE" 2>&1 \
      | tee /dev/stderr) || true
  fi

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
