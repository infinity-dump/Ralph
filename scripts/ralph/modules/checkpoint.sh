# Ralph checkpoint helpers (sourced by ralph.sh).

ralph_checkpoint_enabled() {
  case "${RALPH_CHECKPOINT:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_checkpoint_file() {
  echo "${RALPH_CHECKPOINT_FILE:-.ralph-checkpoint.json}"
}

ralph_checkpoint_interval() {
  local interval="${RALPH_CHECKPOINT_EVERY:-${RALPH_CHECKPOINT_INTERVAL:-1}}"
  if [[ "$interval" =~ ^[0-9]+$ ]] && (( interval > 0 )); then
    echo "$interval"
  else
    echo "1"
  fi
}

ralph_checkpoint_should_write() {
  local iteration="${1:-}"
  local interval
  interval="$(ralph_checkpoint_interval)"

  if [[ ! "$iteration" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if (( interval <= 0 )); then
    return 1
  fi

  if (( iteration % interval == 0 )); then
    return 0
  fi

  return 1
}

ralph_checkpoint_json_escape() {
  local value="${1:-}"

  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$value" | jq -Rsa '.'
    return 0
  fi

  local escaped="${value//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  escaped="${escaped//$'\n'/\\n}"
  escaped="${escaped//$'\r'/\\r}"
  escaped="${escaped//$'\t'/\\t}"
  printf '"%s"' "$escaped"
}

ralph_checkpoint_write() {
  local iteration="${1:-0}"
  local max_iterations="${2:-0}"
  local current_story_id="${3:-}"
  local current_story_title="${4:-}"
  local last_completed_id="${5:-}"
  local last_completed_title="${6:-}"
  local timestamp="${7:-}"
  local failures_total="${8:-0}"
  local failures_consecutive="${9:-0}"
  local failures_last_reason="${10:-}"
  local failures_last_exit="${11:-0}"

  local file
  file="$(ralph_checkpoint_file)"
  local dir
  dir="$(dirname "$file")"
  if [[ -n "$dir" && "$dir" != "." ]]; then
    mkdir -p "$dir"
  fi

  local timestamp_json
  local current_id_json
  local current_title_json
  local last_id_json
  local last_title_json
  local last_reason_json

  timestamp_json="$(ralph_checkpoint_json_escape "$timestamp")"
  current_id_json="$(ralph_checkpoint_json_escape "$current_story_id")"
  current_title_json="$(ralph_checkpoint_json_escape "$current_story_title")"
  last_id_json="$(ralph_checkpoint_json_escape "$last_completed_id")"
  last_title_json="$(ralph_checkpoint_json_escape "$last_completed_title")"
  last_reason_json="$(ralph_checkpoint_json_escape "$failures_last_reason")"

  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" <<EOF
{
  "iteration": ${iteration},
  "maxIterations": ${max_iterations},
  "timestamp": ${timestamp_json},
  "currentStoryId": ${current_id_json},
  "currentStoryTitle": ${current_title_json},
  "lastCompletedStoryId": ${last_id_json},
  "lastCompletedStoryTitle": ${last_title_json},
  "failures": {
    "total": ${failures_total},
    "consecutive": ${failures_consecutive},
    "lastExit": ${failures_last_exit},
    "lastReason": ${last_reason_json}
  }
}
EOF

  mv -f "$tmp" "$file"
}

ralph_checkpoint_clear() {
  local file
  file="$(ralph_checkpoint_file)"
  rm -f "$file"
}

ralph_checkpoint_load() {
  local file
  file="$(ralph_checkpoint_file)"

  if [[ ! -f "$file" ]]; then
    echo "Checkpoint file not found: $file" >&2
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    RALPH_CHECKPOINT_ITERATION="$(jq -r '.iteration // 0' "$file")"
    RALPH_CHECKPOINT_LAST_COMPLETED_ID="$(jq -r '.lastCompletedStoryId // empty' "$file")"
    RALPH_CHECKPOINT_LAST_COMPLETED_TITLE="$(jq -r '.lastCompletedStoryTitle // empty' "$file")"
    RALPH_CHECKPOINT_CURRENT_STORY_ID="$(jq -r '.currentStoryId // empty' "$file")"
    RALPH_CHECKPOINT_CURRENT_STORY_TITLE="$(jq -r '.currentStoryTitle // empty' "$file")"
    RALPH_CHECKPOINT_FAILURES_TOTAL="$(jq -r '.failures.total // 0' "$file")"
    RALPH_CHECKPOINT_FAILURES_CONSECUTIVE="$(jq -r '.failures.consecutive // 0' "$file")"
    RALPH_CHECKPOINT_FAILURES_LAST_REASON="$(jq -r '.failures.lastReason // empty' "$file")"
    RALPH_CHECKPOINT_FAILURES_LAST_EXIT="$(jq -r '.failures.lastExit // 0' "$file")"
  else
    RALPH_CHECKPOINT_ITERATION="$(sed -n 's/.*"iteration"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$file" | head -n1)"
    RALPH_CHECKPOINT_LAST_COMPLETED_ID="$(sed -n 's/.*"lastCompletedStoryId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n1)"
    RALPH_CHECKPOINT_LAST_COMPLETED_TITLE="$(sed -n 's/.*"lastCompletedStoryTitle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n1)"
    RALPH_CHECKPOINT_CURRENT_STORY_ID="$(sed -n 's/.*"currentStoryId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n1)"
    RALPH_CHECKPOINT_CURRENT_STORY_TITLE="$(sed -n 's/.*"currentStoryTitle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n1)"
    RALPH_CHECKPOINT_FAILURES_TOTAL="$(sed -n 's/.*"total"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$file" | head -n1)"
    RALPH_CHECKPOINT_FAILURES_CONSECUTIVE="$(sed -n 's/.*"consecutive"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$file" | head -n1)"
    RALPH_CHECKPOINT_FAILURES_LAST_EXIT="$(sed -n 's/.*"lastExit"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$file" | head -n1)"
    RALPH_CHECKPOINT_FAILURES_LAST_REASON="$(sed -n 's/.*"lastReason"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n1)"
  fi

  if [[ ! "$RALPH_CHECKPOINT_ITERATION" =~ ^[0-9]+$ ]]; then
    RALPH_CHECKPOINT_ITERATION=0
  fi
  if [[ ! "$RALPH_CHECKPOINT_FAILURES_TOTAL" =~ ^[0-9]+$ ]]; then
    RALPH_CHECKPOINT_FAILURES_TOTAL=0
  fi
  if [[ ! "$RALPH_CHECKPOINT_FAILURES_CONSECUTIVE" =~ ^[0-9]+$ ]]; then
    RALPH_CHECKPOINT_FAILURES_CONSECUTIVE=0
  fi
  if [[ ! "$RALPH_CHECKPOINT_FAILURES_LAST_EXIT" =~ ^[0-9]+$ ]]; then
    RALPH_CHECKPOINT_FAILURES_LAST_EXIT=0
  fi

  return 0
}
