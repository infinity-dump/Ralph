#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="${PROMPT_FILE:-$SCRIPT_DIR/prompt.md}"
PRD_FILE="${PRD_FILE:-$SCRIPT_DIR/prd.json}"
PROGRESS_FILE="${PROGRESS_FILE:-$SCRIPT_DIR/progress.txt}"
MODULE_DIR="$SCRIPT_DIR/modules"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

ralph_init_templates() {
  local force=0

  case "${1:-}" in
    --force)
      force=1
      shift
      ;;
    --help|-h)
      cat <<EOF
Usage: $(basename "$0") init [--force]
Copies template files from ${TEMPLATE_DIR} into ${SCRIPT_DIR}.
EOF
      return 0
      ;;
  esac

  local -a mappings=(
    "prd-template.json:prd.json"
    "prompt-template.md:prompt.md"
    "progress-template.txt:progress.txt"
  )
  local map
  local missing=0
  local copied=0

  for map in "${mappings[@]}"; do
    local src="$TEMPLATE_DIR/${map%%:*}"
    local dest="$SCRIPT_DIR/${map##*:}"

    if [[ ! -f "$src" ]]; then
      echo "Missing template: $src" >&2
      missing=1
      continue
    fi

    if [[ -f "$dest" && "$force" -ne 1 ]]; then
      echo "Exists, skipping: $dest" >&2
      continue
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "Wrote $dest"
    copied=1
  done

  if (( missing == 1 )); then
    return 1
  fi

  if (( copied == 0 )); then
    echo "No files copied. Use --force to overwrite existing files." >&2
  fi
}

if [[ "${1:-}" == "init" ]]; then
  shift
  ralph_init_templates "$@"
  exit $?
fi

if [[ "${1:-}" == "generate-prd" ]]; then
  shift
  if [[ -f "$MODULE_DIR/prd-generator.sh" ]]; then
    # shellcheck source=./modules/prd-generator.sh
    source "$MODULE_DIR/prd-generator.sh"
  else
    echo "Missing module: $MODULE_DIR/prd-generator.sh" >&2
    exit 1
  fi

  ralph_prd_generator_main "$PRD_FILE" "$@"
  exit $?
fi

RESUME=0
if [[ "${1:-}" == "--resume" ]]; then
  RESUME=1
  shift
fi

MAX_ITERATIONS_ARG="${1:-}"

if [[ -f "$MODULE_DIR/circuit-breaker.sh" ]]; then
  # shellcheck source=./modules/circuit-breaker.sh
  source "$MODULE_DIR/circuit-breaker.sh"
fi
if [[ -f "$MODULE_DIR/quality-gates.sh" ]]; then
  # shellcheck source=./modules/quality-gates.sh
  source "$MODULE_DIR/quality-gates.sh"
fi
if [[ -f "$MODULE_DIR/planner.sh" ]]; then
  # shellcheck source=./modules/planner.sh
  source "$MODULE_DIR/planner.sh"
fi
if [[ -f "$MODULE_DIR/reviewer.sh" ]]; then
  # shellcheck source=./modules/reviewer.sh
  source "$MODULE_DIR/reviewer.sh"
fi
if [[ -f "$MODULE_DIR/git-guard.sh" ]]; then
  # shellcheck source=./modules/git-guard.sh
  source "$MODULE_DIR/git-guard.sh"
fi
if [[ -f "$MODULE_DIR/parallel.sh" ]]; then
  # shellcheck source=./modules/parallel.sh
  source "$MODULE_DIR/parallel.sh"
fi
if [[ -f "$MODULE_DIR/checkpoint.sh" ]]; then
  # shellcheck source=./modules/checkpoint.sh
  source "$MODULE_DIR/checkpoint.sh"
fi
if [[ -f "$MODULE_DIR/cache.sh" ]]; then
  # shellcheck source=./modules/cache.sh
  source "$MODULE_DIR/cache.sh"
fi
if [[ -f "$MODULE_DIR/cost-control.sh" ]]; then
  # shellcheck source=./modules/cost-control.sh
  source "$MODULE_DIR/cost-control.sh"
fi

extract_progress_patterns() {
  local progress_file="$1"

  if [[ ! -f "$progress_file" ]]; then
    return 0
  fi

  awk '
    BEGIN {found=0}
    /^##[[:space:]]+Codebase Patterns/ {found=1; next}
    found && /^##[[:space:]]+/ {exit}
    found {print}
  ' "$progress_file"
}

build_iteration_context() {
  local iteration="$1"
  local max_iterations="$2"
  local timestamp="$3"
  local git_branch
  local git_sha
  local git_status
  local patterns_raw
  local patterns

  git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  git_sha="$(git rev-parse --short HEAD 2>/dev/null || true)"
  git_status="$(git -c color.status=false status -sb 2>/dev/null || true)"
  patterns_raw="$(extract_progress_patterns "$PROGRESS_FILE")"

  printf "%s\n" "# Ralph Iteration Context"
  printf "Iteration: %s / %s\n" "$iteration" "$max_iterations"
  printf "Timestamp: %s\n" "$timestamp"
  if [[ -n "${RALPH_PHASE_CURRENT:-}" ]]; then
    printf "Phase: %s\n" "$RALPH_PHASE_CURRENT"
  fi
  printf "Git Branch: %s\n" "${git_branch:-unknown}"
  printf "Git Commit: %s\n" "${git_sha:-unknown}"
  printf "\nGit Status:\n%s\n\n" "${git_status:-Unavailable}"

  if [[ "${RALPH_CONTEXT_SUMMARY:-}" == "1" ]]; then
    patterns="$(printf "%s\n" "$patterns_raw" | sed '/^[[:space:]]*$/d')"
    if [[ -n "$patterns" ]]; then
      printf "Codebase Patterns (from progress.txt):\n%s\n\n" "$patterns"
    fi
  fi
}

select_story() {
  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  local phase=""
  local include_unassigned="1"
  if [[ "${RALPH_PHASE_CHAINING_ACTIVE:-0}" == "1" ]]; then
    phase="${RALPH_PHASE_CURRENT:-}"
    include_unassigned="${RALPH_PHASE_INCLUDE_UNSPECIFIED:-1}"
    if [[ ! "$include_unassigned" =~ ^[0-9]+$ ]]; then
      include_unassigned="1"
    fi
  fi

  local target_story="${RALPH_STORY_ID:-${RALPH_TARGET_STORY:-}}"
  if [[ -n "$target_story" ]]; then
    jq -c --arg id "$target_story" '
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
      | map(select(.story.id == $id))
      | .[0] // empty
    ' "$PRD_FILE" 2>/dev/null || true
    return 0
  fi

  jq -c --arg phase "$phase" --argjson include_unassigned "$include_unassigned" '
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
    def phase_list:
      if (.phase | type) == "string" then [ .phase ]
      elif (.phases | type) == "array" then .phases
      elif (.tags | type) == "array" then .tags
      else [] end;
    def in_phase($phase; $include_unassigned):
      if $phase == "" then true
      else
        (phase_list | index($phase) != null)
        or ($include_unassigned == 1 and (phase_list | length == 0))
      end;

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
    | map(select(.story | in_phase($phase; $include_unassigned)))
    | sort_by(.priority, .index)
    | .[0] // empty
  ' "$PRD_FILE" 2>/dev/null || true
}

story_passed() {
  local story_id="$1"

  if [[ -z "$story_id" ]]; then
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  jq -e --arg id "$story_id" \
    '.userStories[] | select(.id == $id) | .passes == true' \
    "$PRD_FILE" >/dev/null 2>&1
}

detect_model_name() {
  if [[ -n "${RALPH_AGENT:-}" ]]; then
    ralph_agent_normalize "$RALPH_AGENT"
    return
  fi

  if [[ -n "${AGENT_CMD[0]:-}" ]]; then
    ralph_agent_normalize "$(basename "${AGENT_CMD[0]}")"
  fi
}

ralph_agent_normalize() {
  local name="${1:-}"

  name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
  case "$name" in
    "")
      echo ""
      ;;
    codex*)
      echo "codex"
      ;;
    claude*)
      echo "claude"
      ;;
    aider*)
      echo "aider"
      ;;
    custom)
      echo "custom"
      ;;
    *)
      echo "$name"
      ;;
  esac
}

ralph_agent_prompt_context() {
  local agent="$1"

  case "$agent" in
    codex)
      cat <<'EOF'
# Agent Preset
Agent: codex
Notes: Running via Codex CLI in non-interactive mode.
EOF
      ;;
    claude)
      cat <<'EOF'
# Agent Preset
Agent: claude
Notes: Running via Claude Code CLI in non-interactive mode.
EOF
      ;;
    aider)
      cat <<'EOF'
# Agent Preset
Agent: aider
Notes: Running via Aider in batch mode; avoid interactive prompts.
EOF
      ;;
  esac
}

ralph_agent_apply_preset() {
  local preset="$1"

  case "$preset" in
    codex)
      AGENT_CMD=(codex exec --dangerously-bypass-approvals-and-sandbox)
      AGENT_INPUT_MODE="stdin"
      AGENT_INPUT_ARG="-"
      AGENT_SKIP_GIT_ARG="--skip-git-repo-check"
      AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "codex")"
      return 0
      ;;
    claude)
      AGENT_CMD=(claude --dangerously-skip-permissions)
      AGENT_INPUT_MODE="stdin"
      AGENT_INPUT_ARG=""
      AGENT_SKIP_GIT_ARG=""
      AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "claude")"
      return 0
      ;;
    aider)
      AGENT_CMD=(aider --message-file)
      AGENT_INPUT_MODE="file"
      AGENT_INPUT_ARG=""
      AGENT_SKIP_GIT_ARG=""
      AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "aider")"
      return 0
      ;;
  esac

  return 1
}

ralph_register_exit_trap() {
  local handlers=()
  if declare -F ralph_git_guard_cleanup >/dev/null 2>&1; then
    handlers+=("ralph_git_guard_cleanup")
  fi
  if declare -F ralph_cost_control_report >/dev/null 2>&1; then
    handlers+=("ralph_cost_control_report")
  fi
  if (( ${#handlers[@]} > 0 )); then
    local cmd=""
    local handler
    for handler in "${handlers[@]}"; do
      cmd+="${handler};"
    done
    trap "$cmd" EXIT
  fi
}

ralph_single_story_enabled() {
  case "${RALPH_SINGLE_STORY:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Default agent command; override via RALPH_AGENT or RALPH_AGENT_CMD.
# Use codex exec for non-interactive (headless) runs.
AGENT_CMD=()
AGENT_INPUT_MODE="stdin"
AGENT_INPUT_ARG="-"
AGENT_SKIP_GIT_ARG=""
AGENT_PROMPT_CONTEXT=""
RALPH_AGENT_PRESET="$(ralph_agent_normalize "${RALPH_AGENT:-}")"

if [[ -n "${RALPH_AGENT_CMD:-}" ]]; then
  # shellcheck disable=SC2206
  AGENT_CMD=(${RALPH_AGENT_CMD})
  AGENT_INPUT_MODE="stdin"
  AGENT_INPUT_ARG="-"
  if [[ -n "$RALPH_AGENT_PRESET" ]]; then
    AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "$RALPH_AGENT_PRESET")"
  else
    INFERRED_AGENT="$(ralph_agent_normalize "$(basename "${AGENT_CMD[0]}")")"
    AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "$INFERRED_AGENT")"
    if [[ "$INFERRED_AGENT" == "codex" ]]; then
      AGENT_SKIP_GIT_ARG="--skip-git-repo-check"
    fi
  fi
else
  if [[ -z "$RALPH_AGENT_PRESET" ]]; then
    RALPH_AGENT_PRESET="codex"
  fi

  if [[ "$RALPH_AGENT_PRESET" == "custom" ]]; then
    echo "RALPH_AGENT=custom requires RALPH_AGENT_CMD to be set." >&2
    exit 1
  fi

  if ! ralph_agent_apply_preset "$RALPH_AGENT_PRESET"; then
    echo "Unknown RALPH_AGENT '$RALPH_AGENT'. Use codex|claude|aider|custom or set RALPH_AGENT_CMD." >&2
    exit 1
  fi
fi

REVIEW_CMD=("${AGENT_CMD[@]}")
if [[ -n "${RALPH_REVIEWER_CMD:-}" ]]; then
  # shellcheck disable=SC2206
  REVIEW_CMD=(${RALPH_REVIEWER_CMD})
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ "${RALPH_SKIP_GIT_CHECK:-}" == "1" ]]; then
    if [[ -n "$AGENT_SKIP_GIT_ARG" ]]; then
      AGENT_CMD+=("$AGENT_SKIP_GIT_ARG")
    fi
  else
    echo "Not a git repo. Initialize with: git init" >&2
    if [[ -n "$AGENT_SKIP_GIT_ARG" ]]; then
      echo "Or run with RALPH_SKIP_GIT_CHECK=1 to pass ${AGENT_SKIP_GIT_ARG}." >&2
    else
      echo "Or run with RALPH_SKIP_GIT_CHECK=1 to bypass the Git check." >&2
    fi
    exit 1
  fi
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
AGENTS_FILE=""
if [[ -n "$REPO_ROOT" && -f "$REPO_ROOT/AGENTS.md" ]]; then
  AGENTS_FILE="$REPO_ROOT/AGENTS.md"
fi

TARGET_STORY="${RALPH_STORY_ID:-${RALPH_TARGET_STORY:-}}"
if [[ -n "$TARGET_STORY" ]] && ! command -v jq >/dev/null 2>&1; then
  echo "Targeted story selection requires jq (RALPH_STORY_ID=$TARGET_STORY)." >&2
  exit 1
fi

if declare -F ralph_cost_control_task_max_iterations >/dev/null 2>&1; then
  TASK_TYPE_MAX="$(ralph_cost_control_task_max_iterations || true)"
  if [[ -n "$TASK_TYPE_MAX" && -z "$MAX_ITERATIONS_ARG" && -z "${MAX_ITERATIONS:-}" ]]; then
    MAX_ITERATIONS_ARG="$TASK_TYPE_MAX"
  fi
fi

if declare -F ralph_git_guard_enable >/dev/null 2>&1; then
  ralph_git_guard_enable
fi

if declare -F ralph_circuit_breaker_init >/dev/null 2>&1; then
  ralph_circuit_breaker_init "$MAX_ITERATIONS_ARG"
  MODEL_NAME="$(detect_model_name)"
  ralph_circuit_breaker_apply_model_limit "$MODEL_NAME"
  MAX_ITERATIONS="$RALPH_CB_MAX_ITERATIONS"
else
  MAX_ITERATIONS="${MAX_ITERATIONS_ARG:-${MAX_ITERATIONS:-10}}"
fi

if declare -F ralph_cost_control_init >/dev/null 2>&1; then
  ralph_cost_control_init
fi

ralph_register_exit_trap

SINGLE_STORY_MODE=0
if ralph_single_story_enabled; then
  SINGLE_STORY_MODE=1
fi

if declare -F ralph_parallel_enabled >/dev/null 2>&1 && ralph_parallel_enabled; then
  echo "Parallel execution enabled."
  if declare -F ralph_parallel_run >/dev/null 2>&1; then
    if ralph_parallel_run "$PRD_FILE"; then
      exit 0
    else
      exit 1
    fi
  else
    echo "Parallel module not available; disable RALPH_PARALLEL or add modules/parallel.sh." >&2
    exit 1
  fi
fi

START_ITERATION=1
LAST_COMPLETED_STORY_ID=""
LAST_COMPLETED_STORY_TITLE=""
FAILURE_TOTAL=0
FAILURE_CONSECUTIVE=0
LAST_FAILURE_REASON=""
LAST_FAILURE_EXIT=0

if [[ "$RESUME" -eq 1 ]]; then
  if ! declare -F ralph_checkpoint_load >/dev/null 2>&1; then
    echo "Checkpoint module not available; cannot resume." >&2
    exit 1
  fi

  if ! ralph_checkpoint_load; then
    exit 1
  fi

  START_ITERATION=$((RALPH_CHECKPOINT_ITERATION + 1))
  LAST_COMPLETED_STORY_ID="${RALPH_CHECKPOINT_LAST_COMPLETED_ID:-}"
  LAST_COMPLETED_STORY_TITLE="${RALPH_CHECKPOINT_LAST_COMPLETED_TITLE:-}"
  FAILURE_TOTAL="${RALPH_CHECKPOINT_FAILURES_TOTAL:-0}"
  FAILURE_CONSECUTIVE="${RALPH_CHECKPOINT_FAILURES_CONSECUTIVE:-0}"
  LAST_FAILURE_REASON="${RALPH_CHECKPOINT_FAILURES_LAST_REASON:-}"
  LAST_FAILURE_EXIT="${RALPH_CHECKPOINT_FAILURES_LAST_EXIT:-0}"

  if [[ -n "${RALPH_CB_CONSECUTIVE_FAILURES+x}" ]]; then
    RALPH_CB_CONSECUTIVE_FAILURES="$FAILURE_CONSECUTIVE"
  fi
  if [[ -n "${RALPH_CB_LAST_FAILURE_REASON+x}" ]]; then
    RALPH_CB_LAST_FAILURE_REASON="$LAST_FAILURE_REASON"
  fi
  if [[ -n "${RALPH_CB_LAST_EXIT+x}" ]]; then
    RALPH_CB_LAST_EXIT="$LAST_FAILURE_EXIT"
  fi

  if (( START_ITERATION > MAX_ITERATIONS )); then
    echo "Checkpoint iteration ${RALPH_CHECKPOINT_ITERATION} exceeds max iterations (${MAX_ITERATIONS})." >&2
    echo "Increase MAX_ITERATIONS or remove $(ralph_checkpoint_file)." >&2
    exit 1
  fi

  echo "Resuming from checkpoint $(ralph_checkpoint_file) at iteration ${RALPH_CHECKPOINT_ITERATION}."
  if [[ -n "$LAST_COMPLETED_STORY_ID" ]]; then
    echo "Last completed story: ${LAST_COMPLETED_STORY_ID} ${LAST_COMPLETED_STORY_TITLE:+- $LAST_COMPLETED_STORY_TITLE}"
  fi
fi

echo "Starting Ralph (max iterations: $MAX_ITERATIONS)"

for i in $(seq "$START_ITERATION" "$MAX_ITERATIONS"); do
  ITERATION_TS="$(date +'%Y-%m-%d %H:%M:%S')"
  echo "=== Iteration $i / $MAX_ITERATIONS ($ITERATION_TS) ==="
  if declare -F ralph_cost_control_iteration_start >/dev/null 2>&1; then
    ralph_cost_control_iteration_start
  fi
  if declare -F ralph_circuit_breaker_warn_if_needed >/dev/null 2>&1; then
    ralph_circuit_breaker_warn_if_needed "$i"
  fi

  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Missing prompt file: $PROMPT_FILE" >&2
    exit 1
  fi
  if [[ ! -f "$PRD_FILE" ]]; then
    echo "Missing prd file: $PRD_FILE" >&2
    exit 1
  fi
  if [[ ! -f "$PROGRESS_FILE" ]]; then
    echo "Missing progress file: $PROGRESS_FILE" >&2
    exit 1
  fi

  if declare -F ralph_cost_control_phase_advance_if_needed >/dev/null 2>&1; then
    if ! ralph_cost_control_phase_advance_if_needed "$PRD_FILE"; then
      echo "Phase verification failed; stopping." >&2
      exit 1
    fi
  fi

  STORY_CONTEXT=""
  STORY_ID=""
  STORY_TITLE=""
  STORY_PRIORITY=""
  STORY_STATUS=""
  STORY_DEPS=""
  STORY_JSON=""
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

  if [[ -n "$TARGET_STORY" ]]; then
    if [[ -z "$STORY_ID" ]]; then
      if story_passed "$TARGET_STORY"; then
        echo "Target story ${TARGET_STORY} already completed."
        exit 0
      fi
      echo "Target story ${TARGET_STORY} not found or not selectable." >&2
      exit 1
    fi
    if [[ "$STORY_STATUS" == "completed" ]]; then
      echo "Target story ${STORY_ID} already completed."
      exit 0
    fi
    if [[ "$STORY_STATUS" == "blocked" ]]; then
      echo "Target story ${STORY_ID} is blocked." >&2
      exit 1
    fi
  fi

  ITERATION_CONTEXT="$(build_iteration_context "$i" "$MAX_ITERATIONS" "$ITERATION_TS")"
  CACHE_CONTEXT=""
  if declare -F ralph_cache_enabled >/dev/null 2>&1 && ralph_cache_enabled; then
    CACHE_CONTEXT="$(ralph_cache_context "$PROGRESS_FILE" "$AGENTS_FILE" || true)"
  fi

  PLAN_PENDING=0
  PLAN_FAILED=0
  PLAN_STATUS=0
  if declare -F ralph_planner_enabled >/dev/null 2>&1 && ralph_planner_enabled; then
    echo "Planning phase enabled."
    ralph_planner_run "$PROMPT_FILE" "$ITERATION_CONTEXT" "$STORY_CONTEXT" "${AGENT_CMD[@]}"
    PLAN_STATUS=$?
    if [[ "$PLAN_STATUS" -eq 2 ]]; then
      PLAN_PENDING=1
    elif [[ "$PLAN_STATUS" -ne 0 ]]; then
      PLAN_FAILED=1
    fi
  fi

  if [[ "$PLAN_PENDING" -eq 1 ]]; then
    PLAN_FILE_DISPLAY="${RALPH_PLAN_FILE:-.ralph-plan.md}"
    if declare -F ralph_planner_plan_file >/dev/null 2>&1; then
      PLAN_FILE_DISPLAY="$(ralph_planner_plan_file)"
    fi
    echo "Plan awaiting manual approval. Review ${PLAN_FILE_DISPLAY} and re-run with RALPH_PLAN_APPROVED=1, add Approved: yes (or ${PLAN_FILE_DISPLAY}.approved), or set RALPH_PLAN_APPROVAL=auto."
    exit 0
  fi

  AGENT_RAN=0
  AGENT_EXIT=0
  OUTPUT=""

  if [[ "$PLAN_FAILED" -eq 0 ]]; then
    PROMPT_INPUT="$(mktemp)"
    {
      printf "%s\n\n" "$ITERATION_CONTEXT"
      if [[ -n "$AGENT_PROMPT_CONTEXT" ]]; then
        printf "%s\n\n" "$AGENT_PROMPT_CONTEXT"
      fi
      if [[ -n "$STORY_CONTEXT" ]]; then
        printf "%s" "$STORY_CONTEXT"
      fi
      if [[ -n "$CACHE_CONTEXT" ]]; then
        printf "%s" "$CACHE_CONTEXT"
      fi
      cat "$PROMPT_FILE"
    } > "$PROMPT_INPUT"

    OUTPUT_FILE="$(mktemp)"
    set +e
    if [[ "$AGENT_INPUT_MODE" == "file" ]]; then
      "${AGENT_CMD[@]}" "$PROMPT_INPUT" 2>&1 \
        | tee /dev/stderr \
        | tee "$OUTPUT_FILE"
      PIPE_STATUS=("${PIPESTATUS[@]}")
      AGENT_EXIT="${PIPE_STATUS[0]:-0}"
    else
      AGENT_INVOKE=("${AGENT_CMD[@]}")
      if [[ -n "$AGENT_INPUT_ARG" ]]; then
        AGENT_INVOKE+=("$AGENT_INPUT_ARG")
      fi
      cat "$PROMPT_INPUT" | "${AGENT_INVOKE[@]}" 2>&1 \
        | tee /dev/stderr \
        | tee "$OUTPUT_FILE"
      PIPE_STATUS=("${PIPESTATUS[@]}")
      AGENT_EXIT="${PIPE_STATUS[1]:-0}"
    fi
    set -e
    OUTPUT="$(cat "$OUTPUT_FILE")"

    rm -f "$OUTPUT_FILE"
    rm -f "$PROMPT_INPUT"
    AGENT_RAN=1
  else
    AGENT_EXIT="${RALPH_PLAN_EXIT:-1}"
    OUTPUT="${RALPH_PLAN_OUTPUT:-}"
  fi

  QUALITY_FAILED=0
  QUALITY_REASON=""
  if [[ "$AGENT_RAN" -eq 1 ]] && declare -F ralph_quality_gates_run >/dev/null 2>&1; then
    if ! ralph_quality_gates_run "$PRD_FILE" "${STORY_ID:-}"; then
      QUALITY_FAILED=1
      QUALITY_REASON="Quality gates failed in strict mode."
    fi
  fi

  REVIEW_FAILED=0
  REVIEW_REASON=""
  if [[ "$AGENT_RAN" -eq 1 ]] \
    && declare -F ralph_reviewer_enabled >/dev/null 2>&1 \
    && ralph_reviewer_enabled \
    && declare -F ralph_reviewer_run >/dev/null 2>&1; then
    if ! ralph_reviewer_run "$ITERATION_CONTEXT" "$STORY_CONTEXT" "$OUTPUT" "${REVIEW_CMD[@]}"; then
      REVIEW_FAILED=1
      REVIEW_REASON="Reviewer command exited with status ${RALPH_REVIEW_EXIT:-unknown}."
      echo "Adversarial review failed (non-blocking): $REVIEW_REASON" >&2
    fi
  fi

  if [[ "$AGENT_RAN" -eq 1 ]] && declare -F ralph_cost_control_record_cost >/dev/null 2>&1; then
    ralph_cost_control_record_cost "$OUTPUT"
    if declare -F ralph_cost_control_enforce_budget >/dev/null 2>&1; then
      if ! ralph_cost_control_enforce_budget; then
        exit 1
      fi
    fi
  fi

  if [[ "$SINGLE_STORY_MODE" -eq 0 ]] && echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    if [[ "$QUALITY_FAILED" -eq 1 ]]; then
      echo "Ignoring COMPLETE because quality gates failed in strict mode." >&2
    else
      HAS_PENDING=1
      if command -v jq >/dev/null 2>&1; then
        if jq -e '.userStories[] | select(.passes == false)' "$PRD_FILE" >/dev/null 2>&1; then
          HAS_PENDING=1
        else
          HAS_PENDING=0
        fi
      fi

      if [[ "$HAS_PENDING" -eq 0 ]]; then
        if declare -F ralph_checkpoint_clear >/dev/null 2>&1; then
          ralph_checkpoint_clear
        fi
        echo "Done!"
        exit 0
      else
        echo "Ignoring COMPLETE because pending stories remain in $PRD_FILE" >&2
      fi
    fi
  fi

  ITERATION_FAILED=0
  FAILURE_REASON=""
  if [[ "$QUALITY_FAILED" -eq 1 ]]; then
    ITERATION_FAILED=1
    FAILURE_REASON="$QUALITY_REASON"
  elif [[ "$AGENT_EXIT" -ne 0 ]]; then
    ITERATION_FAILED=1
    FAILURE_REASON="Agent command exited with status $AGENT_EXIT."
  elif [[ -n "${STORY_ID:-}" ]] && ! story_passed "$STORY_ID"; then
    ITERATION_FAILED=1
    FAILURE_REASON="Story ${STORY_ID} still not marked as passed."
  fi

  if [[ "$ITERATION_FAILED" -eq 1 ]]; then
    FAILURE_TOTAL=$((FAILURE_TOTAL + 1))
    FAILURE_CONSECUTIVE=$((FAILURE_CONSECUTIVE + 1))
    LAST_FAILURE_REASON="$FAILURE_REASON"
    LAST_FAILURE_EXIT="$AGENT_EXIT"
  else
    FAILURE_CONSECUTIVE=0
    if [[ -n "${STORY_ID:-}" ]]; then
      LAST_COMPLETED_STORY_ID="$STORY_ID"
      LAST_COMPLETED_STORY_TITLE="$STORY_TITLE"
    fi
  fi

  if declare -F ralph_checkpoint_enabled >/dev/null 2>&1 && ralph_checkpoint_enabled; then
    if declare -F ralph_checkpoint_should_write >/dev/null 2>&1; then
      if ralph_checkpoint_should_write "$i"; then
        CHECKPOINT_TS="$(date +'%Y-%m-%d %H:%M:%S')"
        ralph_checkpoint_write \
          "$i" \
          "$MAX_ITERATIONS" \
          "${STORY_ID:-}" \
          "${STORY_TITLE:-}" \
          "$LAST_COMPLETED_STORY_ID" \
          "$LAST_COMPLETED_STORY_TITLE" \
          "$CHECKPOINT_TS" \
          "$FAILURE_TOTAL" \
          "$FAILURE_CONSECUTIVE" \
          "$LAST_FAILURE_REASON" \
          "$LAST_FAILURE_EXIT"
      fi
    fi
  fi

  if declare -F ralph_circuit_breaker_record_result >/dev/null 2>&1; then
    ralph_circuit_breaker_record_result \
      "$ITERATION_FAILED" \
      "${STORY_ID:-}" \
      "${STORY_TITLE:-}" \
      "$AGENT_EXIT" \
      "$FAILURE_REASON"

    if ! ralph_circuit_breaker_should_stop "$i"; then
      exit 1
    fi
  fi

  if [[ "$SINGLE_STORY_MODE" -eq 1 && -n "${STORY_ID:-}" ]]; then
    if [[ "$ITERATION_FAILED" -eq 0 ]]; then
      if declare -F ralph_checkpoint_clear >/dev/null 2>&1; then
        ralph_checkpoint_clear
      fi
      echo "Story ${STORY_ID} completed; exiting single-story mode."
      exit 0
    fi
  fi

  if declare -F ralph_cost_control_sleep_between_iterations >/dev/null 2>&1; then
    ralph_cost_control_sleep_between_iterations
  else
    sleep 2
  fi
done

if declare -F ralph_circuit_breaker_report >/dev/null 2>&1; then
  ralph_circuit_breaker_report "max_iterations" "$MAX_ITERATIONS"
fi
echo "Max iterations reached"
exit 1
