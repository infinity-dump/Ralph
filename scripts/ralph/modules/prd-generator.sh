# Ralph PRD generator helpers (sourced by ralph.sh).

ralph_prd_generator_log() {
  echo "[prd-generator] $*"
}

ralph_prd_generator_trim() {
  local text="$1"
  text="$(echo "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  echo "$text"
}

ralph_prd_generator_short_label() {
  local text="$1"
  text="$(ralph_prd_generator_trim "$text")"
  text="${text//$'\n'/ }"
  text="$(echo "$text" | tr -s ' ')"

  local max_len="${RALPH_PRD_TITLE_MAX:-60}"
  if (( ${#text} > max_len )); then
    text="${text:0:max_len}"
    text="${text% *}"
  fi

  if [[ -z "$text" ]]; then
    text="New Feature"
  fi

  echo "$text"
}

ralph_prd_generator_json_escape() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\r'/\\r}"
  text="${text//$'\t'/\\t}"
  echo "$text"
}

ralph_prd_generator_json_array() {
  local out=""
  local item
  for item in "$@"; do
    local escaped
    escaped="$(ralph_prd_generator_json_escape "$item")"
    if [[ -n "$out" ]]; then
      out+=", "
    fi
    out+="\"${escaped}\""
  done
  echo "[${out}]"
}

ralph_prd_generator_story_json() {
  local id="$1"
  local title="$2"
  local description="$3"
  local priority="$4"
  local deps_json="$5"
  local criteria_json="$6"

  printf '  {\n'
  printf '    "id": "%s",\n' "$(ralph_prd_generator_json_escape "$id")"
  printf '    "title": "%s",\n' "$(ralph_prd_generator_json_escape "$title")"
  printf '    "description": "%s",\n' "$(ralph_prd_generator_json_escape "$description")"
  printf '    "priority": %s,\n' "$priority"
  printf '    "acceptanceCriteria": %s,\n' "$criteria_json"
  printf '    "passes": false,\n'
  printf '    "effort": "small",\n'
  printf '    "files": [],\n'
  printf '    "dependencies": %s,\n' "$deps_json"
  printf '    "status": "pending"\n'
  printf '  }'
}

ralph_prd_generator_reset_state() {
  RALPH_PRD_STORIES=()
  RALPH_PRD_STORY_INDEX=1
  RALPH_PRD_LAST_ID=""
  RALPH_PRD_MAX_STORIES="${RALPH_PRD_MAX_STORIES:-7}"
}

ralph_prd_generator_add_story() {
  local title="$1"
  local description="$2"
  local priority="$3"
  local deps_name="$4"
  local criteria_name="$5"

  if (( RALPH_PRD_STORY_INDEX > RALPH_PRD_MAX_STORIES )); then
    return 1
  fi

  local -n deps_ref="$deps_name"
  local -n criteria_ref="$criteria_name"
  local id
  id="US-$(printf '%03d' "$RALPH_PRD_STORY_INDEX")"
  RALPH_PRD_STORY_INDEX=$((RALPH_PRD_STORY_INDEX + 1))

  local deps_json
  deps_json="$(ralph_prd_generator_json_array "${deps_ref[@]}")"
  local criteria_json
  criteria_json="$(ralph_prd_generator_json_array "${criteria_ref[@]}")"

  RALPH_PRD_STORIES+=("$(ralph_prd_generator_story_json "$id" "$title" "$description" "$priority" "$deps_json" "$criteria_json")")
  RALPH_PRD_LAST_ID="$id"
  return 0
}

ralph_prd_generator_should_use_agent() {
  case "${RALPH_PRD_GENERATOR_AGENT:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_prd_generator_resolve_agent_cmd() {
  if [[ -n "${RALPH_PRD_AGENT_CMD:-}" ]]; then
    echo "${RALPH_PRD_AGENT_CMD}"
    return 0
  fi

  if [[ -n "${RALPH_AGENT_CMD:-}" ]]; then
    echo "${RALPH_AGENT_CMD}"
    return 0
  fi

  echo "codex exec --dangerously-bypass-approvals-and-sandbox"
}

ralph_prd_generator_generate_with_agent() {
  local description="$1"
  local output="$2"
  local agent_cmd
  agent_cmd="$(ralph_prd_generator_resolve_agent_cmd)"

  # shellcheck disable=SC2206
  local cmd=(${agent_cmd})
  if [[ "${#cmd[@]}" -eq 0 ]]; then
    ralph_prd_generator_log "Agent command not configured; skipping agent generation."
    return 1
  fi

  local prompt
  prompt=$(cat <<'PROMPT'
You are generating a prd.json for Ralph.
Feature description:
"""
PROMPT
)
  prompt+="${description}"
  prompt+=$(cat <<'PROMPT'
"""

Return ONLY valid JSON with this shape:
{
  "title": string,
  "version": string,
  "status": string,
  "created": "YYYY-MM-DD",
  "updated": "YYYY-MM-DD",
  "overview": { "summary": string },
  "userStories": [
    {
      "id": "US-001",
      "title": string,
      "description": string,
      "priority": number,
      "acceptanceCriteria": [string, ...],
      "passes": false,
      "effort": "small"|"medium"|"large",
      "files": [],
      "dependencies": ["US-###", ...],
      "status": "pending"
    }
  ]
}
Requirements:
- Break into 3-7 atomic stories (one feature per story).
- Each story includes 2-4 clear acceptance criteria.
- Keep stories small enough to complete in 1-3 iterations.
PROMPT
)

  local response
  response="$(printf "%s" "$prompt" | "${cmd[@]}" - 2>/dev/null || true)"

  if [[ -z "$response" ]]; then
    ralph_prd_generator_log "Agent returned empty response."
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    if echo "$response" | jq -e . >/dev/null 2>&1; then
      mkdir -p "$(dirname "$output")"
      echo "$response" > "$output"
      return 0
    fi
  fi

  ralph_prd_generator_log "Agent output was not valid JSON; falling back."
  return 1
}

ralph_prd_generator_generate_template() {
  local description="$1"
  local output="$2"
  local clean_desc
  clean_desc="$(ralph_prd_generator_trim "$description")"

  local short_label
  short_label="$(ralph_prd_generator_short_label "$clean_desc")"

  local date
  date="$(date +%Y-%m-%d)"

  local desc_lower
  desc_lower="$(echo "$clean_desc" | tr '[:upper:]' '[:lower:]')"

  local needs_data=0
  local needs_api=0
  local needs_ui=0
  local needs_cli=0

  if echo "$desc_lower" | grep -Eq "database|db|schema|migration|storage|persist"; then
    needs_data=1
  fi
  if echo "$desc_lower" | grep -Eq "api|endpoint|service|integration"; then
    needs_api=1
  fi
  if echo "$desc_lower" | grep -Eq "ui|frontend|page|screen|component|dashboard"; then
    needs_ui=1
  fi
  if echo "$desc_lower" | grep -Eq "cli|command|terminal"; then
    needs_cli=1
  fi

  ralph_prd_generator_reset_state

  local data_id=""
  local core_id=""
  local api_id=""
  local ui_id=""
  local cli_id=""
  local -a deps
  local -a criteria

  if (( needs_data == 1 )); then
    deps=()
    criteria=(
      "Define data model fields and constraints for ${short_label}"
      "Add migrations or storage setup if needed"
      "Validate inputs before persistence"
    )
    if ralph_prd_generator_add_story "Data model for ${short_label}" "Create the data structures needed for ${short_label}." 1 deps criteria; then
      data_id="$RALPH_PRD_LAST_ID"
    else
      ralph_prd_generator_log "Skipping data model story (max stories reached)."
    fi
  fi

  deps=()
  if [[ -n "$data_id" ]]; then
    deps=("$data_id")
  fi
  criteria=(
    "Implement the primary workflow for ${short_label}"
    "Handle expected errors and edge cases"
    "Confirm behavior matches the requested feature"
  )
  if ralph_prd_generator_add_story "Core ${short_label}" "Implement the core behavior for ${short_label}." 1 deps criteria; then
    core_id="$RALPH_PRD_LAST_ID"
  fi

  local -a deliverables
  deliverables=()
  if [[ -n "$core_id" ]]; then
    deliverables+=("$core_id")
  fi

  if (( needs_api == 1 )); then
    deps=("$core_id")
    criteria=(
      "Expose API endpoints for ${short_label}"
      "Return clear success/error responses"
      "Add validation for API inputs"
    )
    if ralph_prd_generator_add_story "API for ${short_label}" "Deliver API support for ${short_label}." 2 deps criteria; then
      api_id="$RALPH_PRD_LAST_ID"
      deliverables+=("$api_id")
    else
      ralph_prd_generator_log "Skipping API story (max stories reached)."
    fi
  fi

  if (( needs_ui == 1 )); then
    deps=("$core_id")
    criteria=(
      "Build UI for ${short_label}"
      "Show loading, success, and error states"
      "Match the expected UX flow"
    )
    if ralph_prd_generator_add_story "UI for ${short_label}" "Add UI for ${short_label}." 2 deps criteria; then
      ui_id="$RALPH_PRD_LAST_ID"
      deliverables+=("$ui_id")
    else
      ralph_prd_generator_log "Skipping UI story (max stories reached)."
    fi
  fi

  if (( needs_cli == 1 )); then
    deps=("$core_id")
    criteria=(
      "Provide CLI commands for ${short_label}"
      "Display clear output and errors"
      "Document usage for each command"
    )
    if ralph_prd_generator_add_story "CLI for ${short_label}" "Add CLI support for ${short_label}." 2 deps criteria; then
      cli_id="$RALPH_PRD_LAST_ID"
      deliverables+=("$cli_id")
    else
      ralph_prd_generator_log "Skipping CLI story (max stories reached)."
    fi
  fi

  deps=("${deliverables[@]}")
  criteria=(
    "Add tests or checks that cover the core ${short_label} flows"
    "Verify edge cases behave correctly"
    "Ensure the feature passes automated validation"
  )
  if ! ralph_prd_generator_add_story "Tests for ${short_label}" "Validate ${short_label} with automated checks." 3 deps criteria; then
    ralph_prd_generator_log "Skipping tests story (max stories reached)."
  fi

  deps=("${deliverables[@]}")
  criteria=(
    "Document usage for ${short_label}"
    "List configuration or setup steps"
    "Note any limitations or follow-ups"
  )
  if ! ralph_prd_generator_add_story "Docs for ${short_label}" "Document ${short_label} for future users." 4 deps criteria; then
    ralph_prd_generator_log "Skipping docs story (max stories reached)."
  fi

  local stories_block=""
  local idx=0
  local story
  for story in "${RALPH_PRD_STORIES[@]}"; do
    if (( idx > 0 )); then
      stories_block+=$',\n'
    fi
    stories_block+="$story"
    idx=$((idx + 1))
  done

  mkdir -p "$(dirname "$output")"
  cat <<EOF > "$output"
{
  "title": "PRD: $(ralph_prd_generator_json_escape "$short_label")",
  "version": "1.0.0",
  "status": "proposed",
  "created": "${date}",
  "updated": "${date}",
  "author": "ralph prd-generator",
  "overview": {
    "summary": "$(ralph_prd_generator_json_escape "$clean_desc")"
  },
  "userStories": [
${stories_block}
  ]
}
EOF
}

ralph_prd_generator_main() {
  local output="$1"
  shift
  local description="$*"

  if [[ -z "$description" ]]; then
    if [[ -t 0 ]]; then
      ralph_prd_generator_log "Usage: ralph.sh generate-prd 'Feature description'"
      return 1
    fi
    description="$(cat)"
  fi

  description="$(ralph_prd_generator_trim "$description")"
  if [[ -z "$description" ]]; then
    ralph_prd_generator_log "Feature description is required."
    return 1
  fi

  if ralph_prd_generator_should_use_agent; then
    ralph_prd_generator_log "Generating PRD via agent (RALPH_PRD_GENERATOR_AGENT=1)."
    if ralph_prd_generator_generate_with_agent "$description" "$output"; then
      ralph_prd_generator_log "PRD generated at $output"
      return 0
    fi
  fi

  ralph_prd_generator_generate_template "$description" "$output"
  ralph_prd_generator_log "PRD generated at $output"
}
