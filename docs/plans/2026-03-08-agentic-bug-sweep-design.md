# Agentic Bug Sweep Design

## Goal

Add a headless Codex-driven bug sweep workflow that repeatedly runs `agentic-tests`, triages findings against existing GitHub issues, creates or consolidates issues, records related same-root-cause issues, and stops after either a fixed iteration budget or too many consecutive dry runs.

## Scope

This workflow belongs in the repository as a reusable automation surface. It is responsible for:

- running a bounded number of headless Codex iterations
- letting Codex choose the next exploration target autonomously
- persisting reports and machine-readable iteration results
- creating new GitHub issues when a new bug is found
- consolidating findings into existing issues when the bug is already tracked
- recording links to related issues when a finding appears to share the same root cause but is still a distinct symptom
- closing duplicates when a canonical issue is selected

It is not responsible for:

- fixing bugs automatically
- pushing branches or creating pull requests
- continuing forever without an explicit iteration bound

## Recommended Approach

Use a shell script as the orchestration layer and use headless Codex only for the judgment-heavy parts.

The shell script should own deterministic operations:

- iteration counting
- lock handling
- environment checks
- report and log storage
- GitHub mutations through `gh`

Codex should own non-deterministic reasoning:

- choosing the next high-yield exploration area
- interpreting `agentic-tests` results
- deciding whether a finding should create a new issue, update an existing issue, merge into a canonical issue, or produce no action
- identifying existing issues that are probably related because they appear to share the same root cause

This split keeps side effects auditable and makes failures easier to recover from than a single fully autonomous prompt.

## Architecture

The workflow should consist of three checked-in files plus artifact directories:

- `scripts/agentic-bug-sweep.sh`
- `ai/agentic-bug-sweep.md`
- `ai/agentic-bug-sweep.schema.json`
- durable artifacts in `docs/test-reports/agentic-bug-sweep/`
- ephemeral state in `target/agentic-bug-sweep/`

`scripts/agentic-bug-sweep.sh` is the entrypoint. It gathers repository context, invokes `codex exec`, validates the returned JSON, and applies GitHub side effects.

`ai/agentic-bug-sweep.md` is the fixed prompt that tells Codex to inspect prior reports, inspect existing issues, choose the next target, run the installed `agentic-tests` flow, and emit only schema-valid JSON.

`ai/agentic-bug-sweep.schema.json` defines the exact contract that the shell script accepts from Codex.

## Iteration Flow

Each iteration should run in this order:

1. Acquire a lock so only one sweep runs at a time.
2. Snapshot relevant GitHub state such as open bug issues and recent issue metadata.
3. Gather prior sweep reports from `docs/test-reports/agentic-bug-sweep/`.
4. Invoke `codex exec` headlessly with:
   - the target repository path
   - the fixed prompt file
   - the JSON schema
   - a durable output file for the last message
5. Validate the returned JSON strictly.
6. Apply the requested GitHub action:
   - `create`: create a new issue
   - `update`: comment on an existing issue
   - `merge`: update the canonical issue, comment on duplicates, and close duplicates
   - `none`: record the dry run and do not mutate GitHub
7. Preserve any same-root-cause relationships returned through `related_issue_numbers`.
8. Persist iteration metadata and report references.
9. Update counters and decide whether to continue.

The shell should never let Codex perform raw GitHub mutations directly. Codex returns intent and payload; the shell applies the side effects.

## Stop Policy

The workflow should use two explicit limits:

- `--iterations N`: hard upper bound for total iterations
- `--max-consecutive-none M`: early-stop threshold for consecutive dry runs

Behavior:

- every iteration consumes one unit from `N`
- `action=none` increments the dry-run counter
- any of `create`, `update`, or `merge` resets the dry-run counter to zero
- the workflow stops as soon as either `N` iterations are reached or `M` consecutive `none` results occur

Stop reasons should be recorded explicitly, for example:

- `completed_max_iterations`
- `completed_consecutive_none_threshold`
- `failed_codex_exec`
- `failed_invalid_json`
- `failed_github_mutation`

## JSON Contract

The Codex output should be minimal and action-oriented. Required top-level fields:

```json
{
  "summary": "short human-readable iteration summary",
  "report_path": "docs/test-reports/bug-sweep-20260308-123456.md",
  "action": "create",
  "issue": {
    "title": "Bug: ...",
    "body": "Markdown body",
    "labels": ["bug", "prio/p1", "area/einsum"]
  },
  "canonical_issue_number": 123,
  "related_issue_numbers": [140, 141],
  "duplicates_to_close": [124, 130],
  "duplicate_comment": "Closing in favor of #123 because ...",
  "issue_comment": "New evidence from automated sweep: ...",
  "related_comment": "This newly discovered bug likely shares the same root cause as #123."
}
```

Contract rules:

- `create`
  - requires `issue`
- `update`
  - requires `canonical_issue_number`
  - requires `issue_comment`
- `merge`
  - requires `canonical_issue_number`
  - requires `issue_comment`
  - requires `duplicates_to_close`
  - requires `duplicate_comment`
- `none`
  - requires only `summary` and `report_path`
- any non-`none` action may include `related_issue_numbers`
- if `related_issue_numbers` is present and the workflow should notify those issues directly, require `related_comment`

The schema should reject any missing fields for the selected action.

## Issue Consolidation Policy

Consolidation should mean operational unification, not a Git merge.

The workflow should distinguish two cases:

- duplicate or same bug
  - use `merge`
- same likely root cause but distinct user-visible bug
  - keep the primary action as `create` or `update`
  - record the relationship through `related_issue_numbers`

When Codex selects `merge`:

1. Comment on the canonical issue with the new evidence.
2. Comment on each duplicate issue with a pointer to the canonical issue.
3. Close each duplicate issue.

This ordering preserves information even if a later GitHub command fails.

When Codex returns `related_issue_numbers`, the workflow should preserve that relationship in the primary issue body or comment, and may also comment on the related issues when `related_comment` is provided.

## Failure Policy

The workflow should stop on the first hard failure.

- If `codex exec` fails, stop and preserve logs.
- If Codex returns invalid JSON, stop and preserve the raw response.
- If a GitHub mutation fails, stop immediately after recording which mutation failed.
- If report generation succeeds but issue mutation fails, keep the report path and iteration payload so the run can be inspected and resumed manually.

The script should prefer conservative failure over silent continuation after partial side effects.

## File Layout

Durable files:

- `docs/test-reports/agentic-bug-sweep/` for reports, iteration summaries, and any audit trail worth keeping

Ephemeral files:

- `target/agentic-bug-sweep/lock`
- `target/agentic-bug-sweep/context/`
- `target/agentic-bug-sweep/output/`

This split keeps long-lived artifacts in versioned paths and temporary execution state out of the main tree.

## Testing Strategy

Verification should focus on deterministic shell behavior and schema enforcement.

- unit-style tests for argument parsing and stop-condition bookkeeping
- tests that stub `codex exec` output and verify `create`, `update`, `merge`, and `none` branches
- tests that verify related-issue handling for same-root-cause findings
- tests that verify duplicate close ordering
- tests that verify early stop on consecutive `none`
- tests that verify failure on invalid JSON or failed `gh` commands

The headless Codex behavior itself should be validated by schema conformance and by preserving raw iteration outputs for inspection.

## Non-Goals

- automatic bug fixing
- automatic branch creation or PR creation
- unbounded autonomous exploration
- opaque direct GitHub mutations from inside Codex prompts

## Recommended Next Step

Implement the shell orchestrator, the fixed prompt, and the schema together. Then add tests that stub `codex exec` and `gh` so the control flow can be validated without making live network mutations.
