# Ralph adversarial reviewer helpers (sourced by ralph.sh).

ralph_reviewer_enabled() {
  case "${RALPH_ADVERSARIAL:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_reviewer_log() {
  echo "[review] $*"
}

ralph_reviewer_run() {
  local iteration_context="$1"
  local story_context="$2"
  local agent_output="$3"
  shift 3
  local reviewer_cmd=("$@")

  if [[ ${#reviewer_cmd[@]} -eq 0 ]]; then
    ralph_reviewer_log "Reviewer command not configured; skipping."
    return 0
  fi

  local git_status
  git_status="$(git -c color.status=false status -sb 2>/dev/null || true)"
  local git_diff
  git_diff="$(git diff --stat 2>/dev/null || true)"

  local review_prompt
  review_prompt="$(mktemp)"

  {
    printf "%s\n\n" "$iteration_context"
    if [[ -n "$story_context" ]]; then
      printf "%s\n" "$story_context"
    fi
    cat <<'PROMPT'
# Ralph Adversarial Review
You are the adversarial reviewer (critic persona). Do NOT implement code or modify files.
Focus your critique on:
- edge cases
- security risks
- logic errors
- missing tests or acceptance-criteria gaps
If no issues are found, say "No issues found" and explain why.

Return concise Markdown with sections:
- Summary
- Findings (bullets with severity if applicable)
- Suggestions (tests or fixes)
PROMPT

    if [[ -n "$git_status" ]]; then
      printf "\n# Git Status\n%s\n" "$git_status"
    fi
    if [[ -n "$git_diff" ]]; then
      printf "\n# Diff Stat\n%s\n" "$git_diff"
    fi
    if [[ -n "$agent_output" ]]; then
      printf "\n# Agent Output\n%s\n" "$agent_output"
    fi
  } > "$review_prompt"

  local output_file
  output_file="$(mktemp)"
  ralph_reviewer_log "Running adversarial review with ${reviewer_cmd[0]}"

  set +e
  if declare -F ralph_colorize_output >/dev/null 2>&1; then
    cat "$review_prompt" | "${reviewer_cmd[@]}" - 2>&1 \
      | tee "$output_file" \
      | ralph_colorize_output
  else
    cat "$review_prompt" | "${reviewer_cmd[@]}" - 2>&1 \
      | tee "$output_file"
  fi
  local pipe_status=("${PIPESTATUS[@]}")
  set -e

  local reviewer_exit="${pipe_status[1]:-0}"
  local output
  output="$(cat "$output_file")"

  rm -f "$review_prompt" "$output_file"

  RALPH_REVIEW_OUTPUT="$output"
  RALPH_REVIEW_EXIT="$reviewer_exit"

  if [[ "$reviewer_exit" -ne 0 ]]; then
    ralph_reviewer_log "Reviewer exited with status $reviewer_exit."
    return 1
  fi

  return 0
}
