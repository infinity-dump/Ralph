# Ralph git safety guard helpers (sourced by ralph.sh).

ralph_git_guard_enabled() {
  case "${RALPH_GIT_GUARD:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_git_guard_bypass() {
  case "${RALPH_GIT_GUARD_BYPASS:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_git_guard_log() {
  echo "[git-guard] $*"
}

ralph_git_guard_cleanup() {
  if [[ -n "${RALPH_GIT_GUARD_DIR:-}" && -d "${RALPH_GIT_GUARD_DIR:-}" ]]; then
    rm -rf "$RALPH_GIT_GUARD_DIR"
  fi
}

ralph_git_guard_enable() {
  if ! ralph_git_guard_enabled; then
    return 0
  fi

  if ralph_git_guard_bypass; then
    ralph_git_guard_log "Bypass enabled; skipping git guard."
    return 0
  fi

  if [[ -n "${RALPH_GIT_GUARD_ACTIVE:-}" ]]; then
    return 0
  fi

  local real_git
  real_git="$(command -v git 2>/dev/null || true)"
  if [[ -z "$real_git" ]]; then
    ralph_git_guard_log "git not found; skipping guard."
    return 0
  fi

  local guard_dir
  if ! guard_dir="$(mktemp -d "${TMPDIR:-/tmp}/ralph-git-guard.XXXXXX" 2>/dev/null)"; then
    ralph_git_guard_log "Failed to create guard directory; skipping guard."
    return 0
  fi
  local wrapper="$guard_dir/git"

  cat >"$wrapper" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

real_git="${RALPH_GIT_GUARD_REAL_GIT:-}"
if [[ -z "$real_git" ]]; then
  echo "[git-guard] Real git path missing; refusing to run." >&2
  exit 1
fi

case "${RALPH_GIT_GUARD_BYPASS:-}" in
  1|true|TRUE|yes|YES)
    exec "$real_git" "$@"
    ;;
esac

args=("$@")
subcommand=""
sub_index=-1
idx=0
while [[ $idx -lt ${#args[@]} ]]; do
  arg="${args[$idx]}"
  if [[ "$arg" == "--" ]]; then
    idx=$((idx + 1))
    subcommand="${args[$idx]:-}"
    sub_index="$idx"
    break
  fi

  if [[ "$arg" == -* ]]; then
    case "$arg" in
      -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix)
        idx=$((idx + 1))
        ;;
      --git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--super-prefix=*)
        ;;
    esac
    idx=$((idx + 1))
    continue
  fi

  subcommand="$arg"
  sub_index="$idx"
  break
done

block() {
  echo "[git-guard] Blocked: $1. Set RALPH_GIT_GUARD_BYPASS=1 to override." >&2
  exit 1
}

if [[ -n "$subcommand" ]]; then
  case "$subcommand" in
    reset)
      idx=$((sub_index + 1))
      while [[ $idx -lt ${#args[@]} ]]; do
        if [[ "${args[$idx]}" == "--hard" ]]; then
          block "git reset --hard"
        fi
        idx=$((idx + 1))
      done
      ;;
    push)
      idx=$((sub_index + 1))
      while [[ $idx -lt ${#args[@]} ]]; do
        case "${args[$idx]}" in
          -f|--force|--force-with-lease|--force-with-lease=*)
            block "git push --force"
            ;;
        esac
        idx=$((idx + 1))
      done
      ;;
    clean)
      idx=$((sub_index + 1))
      while [[ $idx -lt ${#args[@]} ]]; do
        arg="${args[$idx]}"
        if [[ "$arg" == "--force" ]]; then
          block "git clean -f"
        fi
        if [[ "$arg" == -* && "$arg" == *f* ]]; then
          block "git clean -f"
        fi
        idx=$((idx + 1))
      done
      ;;
    branch)
      idx=$((sub_index + 1))
      while [[ $idx -lt ${#args[@]} ]]; do
        if [[ "${args[$idx]}" == "-D" ]]; then
          block "git branch -D"
        fi
        idx=$((idx + 1))
      done
      ;;
  esac
fi

exec "$real_git" "$@"
SH

  chmod +x "$wrapper"

  export RALPH_GIT_GUARD_REAL_GIT="$real_git"
  export RALPH_GIT_GUARD_DIR="$guard_dir"
  export PATH="$guard_dir:$PATH"
  export RALPH_GIT_GUARD_ACTIVE=1

  ralph_git_guard_log "Enabled git guard."
  return 0
}
