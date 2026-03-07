# CreatePR PR Monitoring Design

## Summary

Add fail-fast PR monitoring to `createpr` so the workflow polls required checks every 30 seconds and stops immediately on the first failure instead of waiting for all jobs to finish.

## Approach

Introduce a dedicated `scripts/monitor-pr-checks.sh` helper that wraps `gh pr checks --required --json ...`.

- Shell responsibilities:
  - poll deterministically every 30 seconds
  - detect `pass`, `pending`, and first `fail`
  - print actionable follow-up hints, including `gh run view <run-id> --log-failed` when available
- Agent responsibilities:
  - inspect the first failure immediately
  - fix it locally
  - rerun relevant local verification
  - push and resume monitoring

## Scope

- Bootstrap the template root with the managed agent-asset files that already exist in the generated repo, so `template-rs` becomes the actual upstream source of truth.
- Update both the template source and the generated repo copy of `createpr`, the PR workflow rules, and the managed-asset manifest.

## Why This Split

The shell can reliably monitor CI state, but it cannot safely perform arbitrary code fixes. Keeping detection in bash and remediation in the agent avoids pretending that CI repair can be fully automated without human-level reasoning.
