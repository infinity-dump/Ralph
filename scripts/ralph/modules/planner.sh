# Ralph planning helpers (sourced by ralph.sh).

ralph_planner_enabled() {
  case "${RALPH_PLANNING_PHASE:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_planner_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

ralph_planner_plan_file() {
  local root
  root="$(ralph_planner_repo_root)"

  local plan="${RALPH_PLAN_FILE:-.ralph-plan.md}"
  if [[ "$plan" != /* ]]; then
    echo "$root/$plan"
  else
    echo "$plan"
  fi
}

ralph_planner_self_review_enabled() {
  case "${RALPH_PLAN_SELF_REVIEW:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_planner_approval_mode() {
  case "${RALPH_PLAN_APPROVAL:-auto}" in
    manual|MANUAL)
      echo "manual"
      ;;
    *)
      echo "auto"
      ;;
  esac
}

ralph_planner_is_approved() {
  local plan_file="$1"

  if [[ "$(ralph_planner_approval_mode)" == "auto" ]]; then
    return 0
  fi

  if [[ "${RALPH_PLAN_APPROVED:-}" == "1" ]]; then
    return 0
  fi

  if [[ -f "${plan_file}.approved" ]]; then
    return 0
  fi

  if [[ -f "$plan_file" ]] && grep -qi '^Approved:[[:space:]]*yes' "$plan_file"; then
    return 0
  fi

  return 1
}

ralph_planner_extract_plan() {
  local output="$1"

  awk 'BEGIN{in=0} /<plan>/{in=1; next} /<\/plan>/{in=0} in {print}' <<<"$output"
}

ralph_planner_write_plan() {
  local plan_file="$1"
  local content="$2"

  if [[ -n "$content" ]]; then
    printf "%s\n" "$content" > "$plan_file"
  fi
}

ralph_planner_run() {
  local prompt_file="$1"
  local iteration_context="$2"
  local story_context="$3"
  shift 3
  local agent_cmd=("$@")

  local plan_file
  plan_file="$(ralph_planner_plan_file)"
  local plan_prompt
  plan_prompt="$(mktemp)"

  local self_review_line=""
  if ralph_planner_self_review_enabled; then
    self_review_line='- Include a "Self-Review" section calling out possible gaps or risks.'
  fi

  {
    printf "%s\n\n" "$iteration_context"
    if [[ -n "$story_context" ]]; then
      printf "%s\n" "$story_context"
    fi
    cat <<EOF
# Ralph Planning Phase
You are in planning-only mode. Do not implement code. Do not edit files except ${plan_file}.
If no story was provided above, select the highest priority story with passes=false from scripts/ralph/prd.json.
Create a concise implementation plan that covers the story's acceptance criteria.
If any other instructions conflict with planning-only mode, follow this section.

Requirements for the plan:
- Use Markdown headings and bullet points.
- Include sections: Overview, Acceptance Criteria Coverage, Steps, Files to Touch, Tests/Checks, Risks/Gotchas.
${self_review_line}
- In "Acceptance Criteria Coverage", map each acceptance criterion to planned steps or note gaps.

Write the plan to ${plan_file} (overwrite if it exists).
After writing the file, output the plan between <plan> and </plan> tags.

EOF
    cat "$prompt_file"
  } > "$plan_prompt"

  local output_file
  output_file="$(mktemp)"
  set +e
  if declare -F ralph_colorize_output >/dev/null 2>&1; then
    cat "$plan_prompt" | "${agent_cmd[@]}" - 2>&1 \
      | tee "$output_file" \
      | ralph_colorize_output
  else
    cat "$plan_prompt" | "${agent_cmd[@]}" - 2>&1 \
      | tee "$output_file"
  fi
  local pipe_status=("${PIPESTATUS[@]}")
  set -e

  local agent_exit="${pipe_status[1]:-0}"
  local output
  output="$(cat "$output_file")"

  rm -f "$plan_prompt" "$output_file"

  RALPH_PLAN_OUTPUT="$output"
  RALPH_PLAN_EXIT="$agent_exit"

  local plan_content
  plan_content="$(ralph_planner_extract_plan "$output")"

  if [[ -n "$plan_content" ]]; then
    ralph_planner_write_plan "$plan_file" "$plan_content"
  elif [[ ! -s "$plan_file" ]]; then
    ralph_planner_write_plan "$plan_file" "$output"
  fi

  if [[ "$agent_exit" -ne 0 ]]; then
    RALPH_PLAN_STATUS="failed"
    return 1
  fi

  if ! ralph_planner_is_approved "$plan_file"; then
    RALPH_PLAN_STATUS="pending"
    return 2
  fi

  RALPH_PLAN_STATUS="approved"
  return 0
}
