# CreatePR Single Coverage Lane Design

## Context

`scripts/create-pr.sh` currently runs both:

- `cargo test --workspace --release`
- `cargo llvm-cov --workspace --json --output-path coverage.json`

for local pre-PR verification. `cargo llvm-cov` already runs the test suite, so the local PR path pays for two heavy test executions.

Issue #4 asks whether the shared local PR workflow should stop requiring both commands locally.

## Goals

- Remove duplicate local test execution from `createpr`.
- Keep local verification aligned with release-mode behavior.
- Preserve the per-file coverage threshold check.
- Keep CI policy unchanged unless strictly necessary.
- Update shared workflow docs so the new local verification contract is explicit.

## Non-Goals

- Changing the CI workflow in `.github/workflows/ci.yml`.
- Changing the coverage threshold policy itself.
- Changing unrelated bootstrap checks unless they are part of the shared PR workflow contract.

## Options

### Option 1: Keep both commands

Leave `cargo test --workspace --release` and `cargo llvm-cov` in local `createpr`.

- Pros: plain release test lane remains explicitly checked locally.
- Cons: duplicates the heaviest part of the pre-PR workflow.

### Option 2: Replace local plain tests with `cargo llvm-cov --release`

Use `cargo llvm-cov --workspace --release --json --output-path coverage.json` as the single heavy local verification lane, then run `python3 scripts/check-coverage.py coverage.json`.

- Pros: removes duplicate local test execution while keeping release-mode coverage runs.
- Cons: still differs from a non-instrumented release test lane, so CI should continue to own plain `cargo test --release`.

### Option 3: Use `cargo llvm-cov --no-report` plus separate export

Split the coverage lane into a no-report test run plus a separate export step.

- Pros: explicit control over phases.
- Cons: adds complexity without solving anything better than Option 2 for this template.

## Decision

Use Option 2.

For local PR creation, `cargo llvm-cov --release` is the right compromise: one heavy lane instead of two, while CI still keeps the plain release test lane as a separate signal.

## Scope of Change

Update these shared PR workflow surfaces:

- `scripts/create-pr.sh`
- `ai/pr-workflow-rules.md`
- `.claude/commands/createpr.md`

The bootstrap script `ai/new-tensor4all-rust-repo/scripts/new-repo.sh` is intentionally out of scope because it is repository creation flow, not PR creation flow.

## Testing Strategy

Add a focused script test for `scripts/create-pr.sh` that proves:

- local verification no longer invokes `cargo test --workspace --release`
- local verification does invoke `cargo llvm-cov --workspace --release --json --output-path coverage.json`
- the generated PR body reflects the updated verification list

Use a temporary repository fixture with fake `git`, `cargo`, and `gh` binaries so the test asserts behavior without creating a real PR.

## Risks

- Local users may assume `llvm-cov --release` is identical to plain release tests.
  Mitigation: document that CI still owns the plain release test lane.
- Future docs may drift back to the old duplicated commands.
  Mitigation: update the command doc and workflow rules in the same change, plus cover the generated PR body in tests.
