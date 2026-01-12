#!/usr/bin/env bash
# monitor.sh - Real-time monitoring dashboard for Ralph
# US-013: Real-Time Monitoring Dashboard
#
# Features:
# - RALPH_MONITOR=1 enables real-time output streaming
# - tmux-based dashboard option
# - Activity stream shows: current iteration, story, status
# - Log tailing for long overnight runs
# - Optional notification on completion/failure via RALPH_NOTIFY
#
# Environment Variables:
#   RALPH_MONITOR=1          Enable real-time monitoring
#   RALPH_MONITOR_MODE=      "stream" (default) or "tmux"
#   RALPH_NOTIFY=1           Enable notifications on completion/failure
#   RALPH_NOTIFY_CMD=        Custom notification command (optional)
#   RALPH_LOG=               Log file path (required for tmux mode)

RALPH_MONITOR_STATUS_FILE="${RALPH_MONITOR_STATUS_FILE:-.ralph-monitor-status}"
RALPH_MONITOR_TMUX_SESSION="${RALPH_MONITOR_TMUX_SESSION:-ralph-monitor}"

ralph_monitor_enabled() {
  case "${RALPH_MONITOR:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_notify_enabled() {
  case "${RALPH_NOTIFY:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_monitor_detect_notify_cmd() {
  if [[ -n "${RALPH_NOTIFY_CMD:-}" ]]; then
    echo "$RALPH_NOTIFY_CMD"
    return 0
  fi

  # macOS
  if command -v terminal-notifier >/dev/null 2>&1; then
    echo "terminal-notifier"
    return 0
  fi

  # macOS fallback using osascript
  if command -v osascript >/dev/null 2>&1; then
    echo "osascript"
    return 0
  fi

  # Linux (freedesktop)
  if command -v notify-send >/dev/null 2>&1; then
    echo "notify-send"
    return 0
  fi

  # WSL/Windows
  if command -v powershell.exe >/dev/null 2>&1; then
    echo "powershell"
    return 0
  fi

  return 1
}

ralph_monitor_send_notification() {
  local title="$1"
  local message="$2"
  local urgency="${3:-normal}"  # low, normal, critical

  if ! ralph_notify_enabled; then
    return 0
  fi

  local notify_cmd
  notify_cmd="$(ralph_monitor_detect_notify_cmd)" || {
    echo "Warning: No notification command available. Install terminal-notifier (macOS), notify-send (Linux), or set RALPH_NOTIFY_CMD." >&2
    return 1
  }

  case "$notify_cmd" in
    terminal-notifier)
      local sound=""
      if [[ "$urgency" == "critical" ]]; then
        sound="-sound default"
      fi
      terminal-notifier -title "$title" -message "$message" -group ralph $sound 2>/dev/null || true
      ;;
    osascript)
      osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
      ;;
    notify-send)
      local urgency_flag="normal"
      case "$urgency" in
        low) urgency_flag="low" ;;
        critical) urgency_flag="critical" ;;
      esac
      notify-send -u "$urgency_flag" "$title" "$message" 2>/dev/null || true
      ;;
    powershell)
      powershell.exe -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); \$template.SelectSingleNode('//text[@id=\"1\"]').InnerText = '$title'; \$template.SelectSingleNode('//text[@id=\"2\"]').InnerText = '$message'; [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Ralph').Show([Windows.UI.Notifications.ToastNotification]::new(\$template))" 2>/dev/null || true
      ;;
    *)
      # Custom command: pass title and message as arguments
      $notify_cmd "$title" "$message" 2>/dev/null || true
      ;;
  esac
}

ralph_monitor_notify_success() {
  local message="${1:-All tasks completed successfully}"
  ralph_monitor_send_notification "Ralph: Success" "$message" "normal"
}

ralph_monitor_notify_failure() {
  local message="${1:-Loop stopped due to failure}"
  ralph_monitor_send_notification "Ralph: Failure" "$message" "critical"
}

ralph_monitor_notify_warning() {
  local message="${1:-Warning during execution}"
  ralph_monitor_send_notification "Ralph: Warning" "$message" "normal"
}

ralph_monitor_write_status() {
  local iteration="$1"
  local max_iterations="$2"
  local story_id="${3:-}"
  local story_title="${4:-}"
  local status="${5:-running}"
  local timestamp="${6:-}"

  if [[ -z "$timestamp" ]]; then
    timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
  fi

  cat > "$RALPH_MONITOR_STATUS_FILE" <<EOF
{
  "iteration": $iteration,
  "max_iterations": $max_iterations,
  "story_id": "${story_id:-null}",
  "story_title": "${story_title:-}",
  "status": "$status",
  "timestamp": "$timestamp",
  "pid": $$
}
EOF
}

ralph_monitor_read_status() {
  if [[ -f "$RALPH_MONITOR_STATUS_FILE" ]]; then
    cat "$RALPH_MONITOR_STATUS_FILE"
  else
    echo "{}"
  fi
}

ralph_monitor_clear_status() {
  rm -f "$RALPH_MONITOR_STATUS_FILE"
}

ralph_monitor_format_activity() {
  local iteration="$1"
  local max_iterations="$2"
  local story_id="${3:-}"
  local story_title="${4:-}"
  local status="${5:-running}"
  local timestamp="${6:-}"

  if [[ -z "$timestamp" ]]; then
    timestamp="$(date +'%H:%M:%S')"
  else
    timestamp="$(echo "$timestamp" | sed 's/.*[[:space:]]//')"
  fi

  local story_display=""
  if [[ -n "$story_id" ]]; then
    story_display="${story_id}"
    if [[ -n "$story_title" ]]; then
      story_display="${story_display} - ${story_title}"
    fi
  else
    story_display="(none)"
  fi

  local status_icon=""
  case "$status" in
    running) status_icon=">" ;;
    success) status_icon="+" ;;
    failed)  status_icon="!" ;;
    paused)  status_icon="~" ;;
    *)       status_icon="-" ;;
  esac

  printf "[%s] %s Iter %d/%d | %s | %s\n" \
    "$timestamp" "$status_icon" "$iteration" "$max_iterations" "$status" "$story_display"
}

ralph_monitor_stream_activity() {
  local iteration="$1"
  local max_iterations="$2"
  local story_id="${3:-}"
  local story_title="${4:-}"
  local status="${5:-running}"
  local timestamp="${6:-}"

  if ! ralph_monitor_enabled; then
    return 0
  fi

  local activity
  activity="$(ralph_monitor_format_activity "$iteration" "$max_iterations" "$story_id" "$story_title" "$status" "$timestamp")"
  echo "$activity"

  ralph_monitor_write_status "$iteration" "$max_iterations" "$story_id" "$story_title" "$status" "$timestamp"
}

ralph_monitor_tmux_available() {
  command -v tmux >/dev/null 2>&1
}

ralph_monitor_tmux_session_exists() {
  tmux has-session -t "$RALPH_MONITOR_TMUX_SESSION" 2>/dev/null
}

ralph_monitor_tmux_start() {
  local log_file="${RALPH_LOG:-}"

  if ! ralph_monitor_tmux_available; then
    echo "tmux not available; falling back to stream mode." >&2
    return 1
  fi

  if [[ -z "$log_file" ]]; then
    echo "RALPH_LOG must be set for tmux monitor mode." >&2
    return 1
  fi

  if ralph_monitor_tmux_session_exists; then
    echo "Monitor session '$RALPH_MONITOR_TMUX_SESSION' already exists."
    return 0
  fi

  # Create tmux session with dashboard layout
  tmux new-session -d -s "$RALPH_MONITOR_TMUX_SESSION" -n "dashboard"

  # Main pane: log tail
  tmux send-keys -t "$RALPH_MONITOR_TMUX_SESSION:dashboard" "echo 'Ralph Monitor - Log Output'; echo '─────────────────────────────'; tail -f \"$log_file\" 2>/dev/null || echo 'Waiting for log file...'" Enter

  # Split horizontally for status
  tmux split-window -t "$RALPH_MONITOR_TMUX_SESSION:dashboard" -v -l 8

  # Status pane: watch status file
  tmux send-keys -t "$RALPH_MONITOR_TMUX_SESSION:dashboard.1" "echo 'Ralph Status'; echo '────────────'; watch -n 1 'if [ -f \"$RALPH_MONITOR_STATUS_FILE\" ]; then cat \"$RALPH_MONITOR_STATUS_FILE\" | jq -r \"\\\"Iteration: \\(.iteration)/\\(.max_iterations)\\nStory: \\(.story_id // \\\"none\\\") - \\(.story_title // \\\"\\\")\\nStatus: \\(.status)\\nUpdated: \\(.timestamp)\\\"\" 2>/dev/null || cat \"$RALPH_MONITOR_STATUS_FILE\"; else echo \"Waiting for Ralph to start...\"; fi'" Enter

  echo "Monitor session '$RALPH_MONITOR_TMUX_SESSION' started."
  echo "Attach with: tmux attach -t $RALPH_MONITOR_TMUX_SESSION"
}

ralph_monitor_tmux_stop() {
  if ralph_monitor_tmux_session_exists; then
    tmux kill-session -t "$RALPH_MONITOR_TMUX_SESSION" 2>/dev/null || true
    echo "Monitor session '$RALPH_MONITOR_TMUX_SESSION' stopped."
  fi
  ralph_monitor_clear_status
}

ralph_monitor_init() {
  if ! ralph_monitor_enabled; then
    return 0
  fi

  local mode="${RALPH_MONITOR_MODE:-stream}"

  case "$mode" in
    tmux)
      if ralph_monitor_tmux_start; then
        echo "Monitor: tmux dashboard started"
      else
        echo "Monitor: falling back to stream mode"
      fi
      ;;
    stream|*)
      echo "Monitor: stream mode enabled"
      ;;
  esac

  ralph_monitor_write_status 0 "${MAX_ITERATIONS:-10}" "" "" "initializing"
}

ralph_monitor_cleanup() {
  ralph_monitor_clear_status
}

ralph_monitor_on_iteration_start() {
  local iteration="$1"
  local max_iterations="$2"
  local story_id="${3:-}"
  local story_title="${4:-}"
  local timestamp="${5:-}"

  ralph_monitor_stream_activity "$iteration" "$max_iterations" "$story_id" "$story_title" "running" "$timestamp"
}

ralph_monitor_on_iteration_end() {
  local iteration="$1"
  local max_iterations="$2"
  local story_id="${3:-}"
  local story_title="${4:-}"
  local status="${5:-success}"
  local timestamp="${6:-}"

  ralph_monitor_stream_activity "$iteration" "$max_iterations" "$story_id" "$story_title" "$status" "$timestamp"
}

ralph_monitor_on_run_complete() {
  local status="$1"
  local reason="${2:-}"
  local iterations="${3:-}"
  local max_iterations="${4:-}"

  if ralph_notify_enabled; then
    case "$status" in
      success)
        local msg="Completed successfully"
        if [[ -n "$iterations" && -n "$max_iterations" ]]; then
          msg="$msg after $iterations/$max_iterations iterations"
        fi
        if [[ -n "$reason" ]]; then
          msg="$msg ($reason)"
        fi
        ralph_monitor_notify_success "$msg"
        ;;
      stopped|failed|error)
        local msg="Stopped"
        if [[ -n "$reason" ]]; then
          msg="$msg: $reason"
        fi
        if [[ -n "$iterations" && -n "$max_iterations" ]]; then
          msg="$msg (iter $iterations/$max_iterations)"
        fi
        ralph_monitor_notify_failure "$msg"
        ;;
      paused)
        ralph_monitor_notify_warning "Paused: ${reason:-manual intervention required}"
        ;;
    esac
  fi

  ralph_monitor_write_status "${iterations:-0}" "${max_iterations:-0}" "" "" "$status"
}

# CLI interface for monitor module
ralph_monitor_cli() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    start)
      RALPH_MONITOR=1
      ralph_monitor_tmux_start
      ;;
    stop)
      ralph_monitor_tmux_stop
      ;;
    status)
      ralph_monitor_read_status
      ;;
    attach)
      if ralph_monitor_tmux_session_exists; then
        tmux attach -t "$RALPH_MONITOR_TMUX_SESSION"
      else
        echo "No monitor session running. Start with: ralph.sh monitor start" >&2
        return 1
      fi
      ;;
    notify)
      local type="${1:-success}"
      local message="${2:-Test notification}"
      RALPH_NOTIFY=1
      case "$type" in
        success) ralph_monitor_notify_success "$message" ;;
        failure) ralph_monitor_notify_failure "$message" ;;
        warning) ralph_monitor_notify_warning "$message" ;;
        *) ralph_monitor_send_notification "Ralph" "$message" ;;
      esac
      ;;
    help|--help|-h)
      cat <<EOF
Ralph Monitor Module - Real-time monitoring dashboard

Commands:
  start     Start tmux monitoring dashboard (requires RALPH_LOG)
  stop      Stop tmux monitoring dashboard
  status    Show current status JSON
  attach    Attach to tmux monitoring session
  notify    Send test notification (notify <type> <message>)
            Types: success, failure, warning

Environment Variables:
  RALPH_MONITOR=1          Enable monitoring
  RALPH_MONITOR_MODE=      "stream" (default) or "tmux"
  RALPH_NOTIFY=1           Enable desktop notifications
  RALPH_NOTIFY_CMD=        Custom notification command
  RALPH_LOG=               Log file (required for tmux mode)

Examples:
  RALPH_LOG=ralph.log ralph.sh monitor start
  ralph.sh monitor attach
  RALPH_NOTIFY=1 ralph.sh monitor notify success "Build completed!"
EOF
      ;;
    *)
      echo "Unknown monitor command: $cmd" >&2
      echo "Use 'ralph.sh monitor help' for usage." >&2
      return 1
      ;;
  esac
}
