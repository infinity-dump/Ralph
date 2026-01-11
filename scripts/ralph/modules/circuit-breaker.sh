# Ralph circuit breaker helpers (sourced by ralph.sh).

ralph_cb_is_number() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

ralph_circuit_breaker_init() {
  local cli_max="${1:-}"
  local env_max="${MAX_ITERATIONS:-}"
  local default_max="10"

  if ralph_cb_is_number "$cli_max"; then
    RALPH_CB_MAX_ITERATIONS="$cli_max"
  elif ralph_cb_is_number "$env_max"; then
    RALPH_CB_MAX_ITERATIONS="$env_max"
  else
    RALPH_CB_MAX_ITERATIONS="$default_max"
  fi
  if (( RALPH_CB_MAX_ITERATIONS < 1 )); then
    RALPH_CB_MAX_ITERATIONS=1
  fi

  local env_warn="${RALPH_WARN_AT:-8}"
  if ralph_cb_is_number "$env_warn"; then
    RALPH_CB_WARN_AT="$env_warn"
  else
    RALPH_CB_WARN_AT="8"
  fi

  local env_consecutive="${MAX_CONSECUTIVE_FAILURES:-3}"
  if ralph_cb_is_number "$env_consecutive"; then
    RALPH_CB_MAX_CONSECUTIVE_FAILURES="$env_consecutive"
  else
    RALPH_CB_MAX_CONSECUTIVE_FAILURES="3"
  fi
  if (( RALPH_CB_MAX_CONSECUTIVE_FAILURES < 1 )); then
    RALPH_CB_MAX_CONSECUTIVE_FAILURES=1
  fi

  RALPH_CB_STUCK_THRESHOLD=3
  RALPH_CB_CONSECUTIVE_FAILURES=0
  RALPH_CB_STUCK_STORY_ID=""
  RALPH_CB_STUCK_FAILURES=0
  RALPH_CB_WARNED=0
  RALPH_CB_LAST_STORY_ID=""
  RALPH_CB_LAST_STORY_TITLE=""
  RALPH_CB_LAST_FAILURE_REASON=""
  RALPH_CB_LAST_EXIT=0
  RALPH_CB_MODEL_LIMIT=""
  RALPH_CB_MODEL_NAME=""
}

ralph_circuit_breaker_apply_model_limit() {
  local model="${1:-}"

  if [[ -z "$model" ]]; then
    return 0
  fi

  local model_key
  model_key="$(echo "$model" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9' '_')"
  local var="RALPH_MODEL_LIMIT_${model_key}"
  local limit="${!var:-}"

  if ralph_cb_is_number "$limit"; then
    RALPH_CB_MODEL_NAME="$model"
    RALPH_CB_MODEL_LIMIT="$limit"
    if (( limit < RALPH_CB_MAX_ITERATIONS )); then
      RALPH_CB_MAX_ITERATIONS="$limit"
    fi
  fi
}

ralph_circuit_breaker_warn_if_needed() {
  local iteration="${1:-}"

  if (( RALPH_CB_WARNED == 0 )) && ralph_cb_is_number "$iteration"; then
    if (( iteration == RALPH_CB_WARN_AT )); then
      echo "Warning: approaching iteration limit (${iteration}/${RALPH_CB_MAX_ITERATIONS})."
      RALPH_CB_WARNED=1
    fi
  fi
}

ralph_circuit_breaker_record_result() {
  local failed="$1"
  local story_id="$2"
  local story_title="$3"
  local exit_code="$4"
  local reason="$5"

  RALPH_CB_LAST_STORY_ID="$story_id"
  RALPH_CB_LAST_STORY_TITLE="$story_title"
  RALPH_CB_LAST_FAILURE_REASON="$reason"
  RALPH_CB_LAST_EXIT="$exit_code"

  if [[ "$failed" -eq 1 ]]; then
    RALPH_CB_CONSECUTIVE_FAILURES=$((RALPH_CB_CONSECUTIVE_FAILURES + 1))
    if [[ -n "$story_id" ]]; then
      if [[ "$story_id" == "$RALPH_CB_STUCK_STORY_ID" ]]; then
        RALPH_CB_STUCK_FAILURES=$((RALPH_CB_STUCK_FAILURES + 1))
      else
        RALPH_CB_STUCK_STORY_ID="$story_id"
        RALPH_CB_STUCK_FAILURES=1
      fi
    else
      RALPH_CB_STUCK_STORY_ID=""
      RALPH_CB_STUCK_FAILURES=0
    fi
  else
    RALPH_CB_CONSECUTIVE_FAILURES=0
    RALPH_CB_STUCK_STORY_ID=""
    RALPH_CB_STUCK_FAILURES=0
  fi
}

ralph_circuit_breaker_should_stop() {
  local iteration="$1"
  local reason=""

  if (( RALPH_CB_CONSECUTIVE_FAILURES >= RALPH_CB_MAX_CONSECUTIVE_FAILURES )); then
    reason="consecutive_failures"
  fi

  if [[ -n "$RALPH_CB_STUCK_STORY_ID" ]] && (( RALPH_CB_STUCK_FAILURES >= RALPH_CB_STUCK_THRESHOLD )); then
    reason="stuck_story"
  fi

  if [[ -n "$reason" ]]; then
    ralph_circuit_breaker_report "$reason" "$iteration"
    return 1
  fi

  return 0
}

ralph_circuit_breaker_report() {
  local reason="$1"
  local iteration="${2:-}"

  echo "=== Ralph Circuit Breaker ==="
  case "$reason" in
    max_iterations)
      echo "Exit reason: max iterations reached (${iteration}/${RALPH_CB_MAX_ITERATIONS})."
      ;;
    consecutive_failures)
      echo "Exit reason: consecutive failures (${RALPH_CB_CONSECUTIVE_FAILURES}/${RALPH_CB_MAX_CONSECUTIVE_FAILURES})."
      ;;
    stuck_story)
      echo "Exit reason: stuck story detected (${RALPH_CB_STUCK_STORY_ID}) failed ${RALPH_CB_STUCK_FAILURES} times."
      ;;
    *)
      echo "Exit reason: ${reason}"
      ;;
  esac

  if [[ -n "$RALPH_CB_LAST_STORY_ID" ]]; then
    echo "Last story: ${RALPH_CB_LAST_STORY_ID} - ${RALPH_CB_LAST_STORY_TITLE:-untitled}"
  fi
  if [[ -n "$RALPH_CB_LAST_FAILURE_REASON" ]]; then
    echo "Last failure: ${RALPH_CB_LAST_FAILURE_REASON}"
  fi
  if [[ -n "$RALPH_CB_MODEL_LIMIT" ]]; then
    echo "Model limit: ${RALPH_CB_MODEL_LIMIT} (model ${RALPH_CB_MODEL_NAME})"
  fi

  echo "Analysis:"
  case "$reason" in
    consecutive_failures)
      echo "- Review the last agent output and fix the recurring failure."
      echo "- Consider reducing scope or clarifying acceptance criteria."
      ;;
    stuck_story)
      echo "- Story has failed repeatedly; consider splitting it into smaller tasks."
      echo "- Verify dependencies, tooling, and update the prompt if needed."
      ;;
    max_iterations)
      echo "- Increase MAX_ITERATIONS if more time is needed."
      echo "- Check progress.txt for repeated blockers."
      ;;
    *)
      echo "- Inspect logs and adjust limits or story scope as needed."
      ;;
  esac
}
