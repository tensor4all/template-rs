#!/usr/bin/env bash
set -euo pipefail

ITERATIONS=""
MAX_CONSECUTIVE_NONE=""
REPO=""
TARGET_WORKDIR=""
MODEL=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROMPT_PATH="${REPO_ROOT}/ai/agentic-bug-sweep.md"
SCHEMA_PATH="${REPO_ROOT}/ai/agentic-bug-sweep.schema.json"
STATE_ROOT="${REPO_ROOT}/target/agentic-bug-sweep"
REPORT_ROOT="${REPO_ROOT}/docs/test-reports/agentic-bug-sweep"

usage() {
  cat <<'EOF'
Usage: bash scripts/agentic-bug-sweep.sh [options]

Options:
  --iterations N              Maximum number of Codex iterations to run
  --max-consecutive-none N    Stop after N consecutive `none` results
  --repo OWNER/REPO           Target GitHub repository slug
  --workdir PATH              Target repository working directory
  --model MODEL               Optional model override for `codex exec`
  --help                      Show this help text
EOF
}

log() {
  printf '%s\n' "$*"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "missing required command: $1"
    exit 1
  fi
}

ensure_inputs() {
  if [[ -z "$ITERATIONS" || -z "$MAX_CONSECUTIVE_NONE" || -z "$REPO" || -z "$TARGET_WORKDIR" ]]; then
    log "missing required arguments"
    usage
    exit 1
  fi
}

ensure_paths() {
  if [[ ! -d "$TARGET_WORKDIR" ]]; then
    log "target workdir does not exist: $TARGET_WORKDIR"
    exit 1
  fi
  if [[ ! -f "$PROMPT_PATH" ]]; then
    log "missing prompt file: $PROMPT_PATH"
    exit 1
  fi
  if [[ ! -f "$SCHEMA_PATH" ]]; then
    log "missing schema file: $SCHEMA_PATH"
    exit 1
  fi
}

ensure_tools() {
  require_command codex
  require_command gh
  gh auth status >/dev/null 2>&1
}

prepare_state_dirs() {
  mkdir -p "${STATE_ROOT}/context"
  mkdir -p "${STATE_ROOT}/output"
  mkdir -p "$REPORT_ROOT"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --max-consecutive-none)
      MAX_CONSECUTIVE_NONE="$2"
      shift 2
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    --workdir)
      TARGET_WORKDIR="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      log "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

ensure_inputs
ensure_paths
ensure_tools
prepare_state_dirs

log "agentic bug sweep scaffolding is ready"
