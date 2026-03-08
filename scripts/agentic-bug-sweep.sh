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
LOCK_PATH="${STATE_ROOT}/lock"

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
  if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || ! [[ "$MAX_CONSECUTIVE_NONE" =~ ^[0-9]+$ ]]; then
    log "--iterations and --max-consecutive-none must be non-negative integers"
    exit 1
  fi
  if [[ "$ITERATIONS" -eq 0 ]]; then
    log "--iterations must be greater than 0"
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
  require_command python3
  gh auth status >/dev/null 2>&1
}

prepare_state_dirs() {
  mkdir -p "${STATE_ROOT}/context"
  mkdir -p "${STATE_ROOT}/output"
  mkdir -p "$REPORT_ROOT"
}

release_lock() {
  rmdir "$LOCK_PATH" >/dev/null 2>&1 || true
}

acquire_lock() {
  if ! mkdir "$LOCK_PATH" >/dev/null 2>&1; then
    log "failed to acquire lock: $LOCK_PATH"
    exit 1
  fi
  trap release_lock EXIT
}

capture_open_issues() {
  gh issue list \
    --repo "$REPO" \
    --state open \
    --label bug \
    --limit 200 \
    --json number,title,body,labels,url >"${STATE_ROOT}/context/open-issues.json"
}

capture_prior_reports() {
  find "$REPORT_ROOT" -maxdepth 1 -type f -name '*.md' | sort >"${STATE_ROOT}/context/prior-reports.txt"
}

validate_json_file() {
  python3 - "$1" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    json.load(handle)
PY
}

json_get_string() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
for part in key.split("."):
    data = data[part]
if isinstance(data, (list, dict)):
    raise SystemExit(f"{key} does not resolve to a scalar")
print(data)
PY
}

json_get_lines() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
for part in key.split("."):
    data = data[part]
if not isinstance(data, list):
    raise SystemExit(f"{key} is not a list")
for item in data:
    print(item)
PY
}

json_has_value() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
try:
    for part in key.split("."):
        data = data[part]
except (KeyError, TypeError):
    raise SystemExit(1)
if data in (None, "", []):
    raise SystemExit(1)
raise SystemExit(0)
PY
}

write_text_with_related() {
  python3 - "$1" "$2" "$3" <<'PY'
import json
import sys

path, key, dest = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
value = data
for part in key.split("."):
    value = value[part]
related = data.get("related_issue_numbers", [])

with open(dest, "w", encoding="utf-8") as handle:
    handle.write(value)
    if related:
        if not value.endswith("\n"):
            handle.write("\n")
        handle.write("\n## Related issues\n\n")
        for issue_number in related:
            handle.write(f"- #{issue_number}\n")
PY
}

write_text_exact() {
  python3 - "$1" "$2" "$3" <<'PY'
import json
import sys

path, key, dest = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
value = data
for part in key.split("."):
    value = value[part]
with open(dest, "w", encoding="utf-8") as handle:
    handle.write(value)
PY
}

create_issue() {
  local result_path="$1"
  local title
  local body_file
  local -a labels
  local -a create_args

  title="$(json_get_string "$result_path" "issue.title")"
  body_file="$(mktemp "${STATE_ROOT}/output/create-body.XXXXXX.md")"
  write_text_with_related "$result_path" "issue.body" "$body_file"
  mapfile -t labels < <(json_get_lines "$result_path" "issue.labels")

  create_args=(issue create --repo "$REPO" --title "$title" --body-file "$body_file")
  for label in "${labels[@]}"; do
    create_args+=(--label "$label")
  done
  if ! gh "${create_args[@]}" >/dev/null; then
    fail_run "failed_github_mutation" "failed to create issue"
  fi
}

update_issue() {
  local result_path="$1"
  local issue_number
  local comment_file

  issue_number="$(json_get_string "$result_path" "canonical_issue_number")"
  comment_file="$(mktemp "${STATE_ROOT}/output/update-comment.XXXXXX.md")"
  write_text_with_related "$result_path" "issue_comment" "$comment_file"
  if ! gh issue comment "$issue_number" --repo "$REPO" --body-file "$comment_file" >/dev/null; then
    fail_run "failed_github_mutation" "failed to comment on issue ${issue_number}"
  fi
}

merge_issue() {
  local result_path="$1"
  local canonical_issue_number
  local canonical_comment_file
  local duplicate_comment_file
  local duplicate_issue_number

  canonical_issue_number="$(json_get_string "$result_path" "canonical_issue_number")"
  canonical_comment_file="$(mktemp "${STATE_ROOT}/output/merge-canonical-comment.XXXXXX.md")"
  duplicate_comment_file="$(mktemp "${STATE_ROOT}/output/merge-duplicate-comment.XXXXXX.md")"

  write_text_with_related "$result_path" "issue_comment" "$canonical_comment_file"
  write_text_exact "$result_path" "duplicate_comment" "$duplicate_comment_file"
  if ! gh issue comment "$canonical_issue_number" --repo "$REPO" --body-file "$canonical_comment_file" >/dev/null; then
    fail_run "failed_github_mutation" "failed to comment on canonical issue ${canonical_issue_number}"
  fi

  while IFS= read -r duplicate_issue_number; do
    if ! gh issue comment "$duplicate_issue_number" --repo "$REPO" --body-file "$duplicate_comment_file" >/dev/null; then
      fail_run "failed_github_mutation" "failed to comment on duplicate issue ${duplicate_issue_number}"
    fi
    if ! gh issue close "$duplicate_issue_number" --repo "$REPO" --reason not planned >/dev/null; then
      fail_run "failed_github_mutation" "failed to close duplicate issue ${duplicate_issue_number}"
    fi
  done < <(json_get_lines "$result_path" "duplicates_to_close")
}

apply_action() {
  local result_path="$1"
  local action="$2"
  case "$action" in
    create)
      create_issue "$result_path"
      ;;
    update)
      update_issue "$result_path"
      ;;
    merge)
      merge_issue "$result_path"
      ;;
    none)
      ;;
    *)
      log "unsupported action: $action"
      exit 1
      ;;
  esac
}

write_run_summary() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import json
import sys

summary_path, iterations_run, consecutive_none_count, stop_reason = sys.argv[1:]
with open(summary_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "iterations_run": int(iterations_run),
            "consecutive_none_count": int(consecutive_none_count),
            "stop_reason": stop_reason,
        },
        handle,
        indent=2,
    )
PY
}

fail_run() {
  local stop_reason="$1"
  local message="$2"

  write_run_summary \
    "${STATE_ROOT}/output/run-summary.json" \
    "$iteration_number" \
    "$consecutive_none_count" \
    "$stop_reason"
  log "$message"
  exit 1
}

run_iteration() {
  local iteration_number="$1"
  local iteration_tag
  local output_path
  local prompt_text
  local -a codex_args

  printf -v iteration_tag '%03d' "$iteration_number"
  output_path="${STATE_ROOT}/output/iteration-${iteration_tag}.json"
  prompt_text="$(cat "$PROMPT_PATH")

Target repository: ${REPO}
Target workdir: ${TARGET_WORKDIR}
Open issues JSON: ${STATE_ROOT}/context/open-issues.json
Prior bug-sweep report index: ${STATE_ROOT}/context/prior-reports.txt"

  codex_args=(exec --cd "$TARGET_WORKDIR" --output-schema "$SCHEMA_PATH" -o "$output_path")
  if [[ -n "$MODEL" ]]; then
    codex_args+=(--model "$MODEL")
  fi
  codex_args+=("$prompt_text")

  if ! codex "${codex_args[@]}"; then
    fail_run "failed_codex_exec" "codex exec failed on iteration ${iteration_number}"
  fi
  if ! validate_json_file "$output_path"; then
    fail_run "failed_invalid_json" "invalid JSON returned by codex on iteration ${iteration_number}"
  fi
  printf '%s\n' "$output_path"
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
acquire_lock

iteration_number=0
consecutive_none_count=0
stop_reason=""

while (( iteration_number < ITERATIONS )); do
  iteration_number=$((iteration_number + 1))
  capture_open_issues
  capture_prior_reports

  iteration_output_path="$(run_iteration "$iteration_number")"
  iteration_action="$(json_get_string "$iteration_output_path" "action")"
  apply_action "$iteration_output_path" "$iteration_action"

  if [[ "$iteration_action" == "none" ]]; then
    consecutive_none_count=$((consecutive_none_count + 1))
    if (( MAX_CONSECUTIVE_NONE > 0 && consecutive_none_count >= MAX_CONSECUTIVE_NONE )); then
      stop_reason="completed_consecutive_none_threshold"
      break
    fi
  else
    consecutive_none_count=0
  fi
done

if [[ -z "$stop_reason" ]]; then
  stop_reason="completed_max_iterations"
fi

write_run_summary \
  "${STATE_ROOT}/output/run-summary.json" \
  "$iteration_number" \
  "$consecutive_none_count" \
  "$stop_reason"

log "agentic bug sweep iteration completed"
