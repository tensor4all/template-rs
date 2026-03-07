# CreatePR PR Monitoring Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add fail-fast PR polling to `createpr` so the agent notices the first CI failure within 30 seconds, fixes it, pushes, and resumes monitoring, and make that behavior available in both the template source and the generated repo.

**Architecture:** Introduce a dedicated shell helper that monitors `gh pr checks` until success or first failure. Keep the shell responsible for deterministic polling and failure detection, and keep the agent responsible for interpreting logs and applying fixes. Bootstrap the template root with the same managed asset bundle currently vendored in the generated repo so future repositories inherit the updated workflow.

**Tech Stack:** Bash, `gh` CLI, Python `unittest`, Markdown agent command files.

---

### Task 1: Add a failing smoke test for PR monitoring

**Files:**
- Create: `tests/test_monitor_pr_checks.py`

**Step 1: Write the failing test**

Add Python `unittest` coverage for a new `scripts/monitor-pr-checks.sh` helper. Cover:
- pending checks followed by success
- first failure exits immediately and surfaces failed check names

Use a temporary fake `gh` executable plus a fake `sleep` executable so the test stays fast and offline.

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_monitor_pr_checks`

Expected: FAIL because `scripts/monitor-pr-checks.sh` does not exist yet.

### Task 2: Implement PR monitoring helper in the template source

**Files:**
- Create: `scripts/monitor-pr-checks.sh`

**Step 1: Write minimal implementation**

Implement a helper that:
- accepts a PR number/url/branch plus optional `--interval`
- polls `gh pr checks --json name,state,link,bucket,workflow`
- exits `0` when all checks pass or are skipped/cancelled
- exits non-zero immediately on the first failed check
- prints the failing check names plus a `gh pr checks`/`gh run view --log-failed` follow-up hint for the agent

**Step 2: Run tests to verify they pass**

Run: `python3 -m unittest tests.test_monitor_pr_checks`

Expected: PASS

### Task 3: Wire the helper into createpr behavior and rules

**Files:**
- Create: `.claude/commands/createpr.md`
- Create: `.claude/commands/check-agent-assets.md`
- Create: `.claude/commands/sync-agent-assets.md`
- Create: `ai/manifest.json`
- Create: `ai/common-agent-rules.md`
- Create: `ai/numerical-rust-rules.md`
- Create: `ai/pr-workflow-rules.md`
- Create: `ai/repo-settings.json`
- Create: `ai/agent-assets.example.lock`
- Create: `scripts/create-pr.sh`
- Create: `scripts/check-agent-assets.sh`
- Create: `scripts/sync-agent-assets.sh`
- Create: `scripts/check-repo-settings.sh`
- Create: `scripts/configure-repo-settings.sh`
- Create: `scripts/check-docs-site.py`
- Create: `scripts/build_docs_site.sh`
- Create: `.github/workflows/docs.yml`
- Modify: `README.md`

**Step 1: Bootstrap the existing managed asset bundle into the template source**

Copy the current agent assets from the generated repo into the template root so `template-rs` becomes the real upstream source of truth.

**Step 2: Update createpr flow**

Modify `scripts/create-pr.sh` to:
- create the PR
- enable auto-merge when configured
- invoke `scripts/monitor-pr-checks.sh --interval 30`
- return a non-success status when a check fails so the agent can inspect logs, fix locally, push, and rerun monitoring

Update `.claude/commands/createpr.md` and `ai/pr-workflow-rules.md` to describe the required poll/fix/resume loop explicitly.

### Task 4: Mirror the same behavior in the generated repo

**Files:**
- Create or modify: `.worktrees/new-tensor4all-rust-repo/.claude/commands/createpr.md`
- Create or modify: `.worktrees/new-tensor4all-rust-repo/scripts/monitor-pr-checks.sh`
- Create or modify: `.worktrees/new-tensor4all-rust-repo/scripts/create-pr.sh`
- Create or modify: `.worktrees/new-tensor4all-rust-repo/ai/manifest.json`
- Create or modify: `.worktrees/new-tensor4all-rust-repo/ai/pr-workflow-rules.md`

**Step 1: Apply the same monitored createpr flow**

Keep the generated repo aligned with the template source immediately, without waiting for a later sync.

**Step 2: Verify mirrored files stay aligned**

Compare the relevant template and generated files after editing.

### Task 5: Verify the changed behavior

**Files:**
- Test: `tests/test_monitor_pr_checks.py`

**Step 1: Run script-focused verification**

Run:

```bash
python3 -m unittest tests.test_monitor_pr_checks
bash scripts/monitor-pr-checks.sh --help
bash .worktrees/new-tensor4all-rust-repo/scripts/monitor-pr-checks.sh --help
```

Expected:
- unit tests pass
- both help commands show polling options and fail-fast monitoring behavior

**Step 2: Run formatting where relevant**

Run: `cargo fmt --all`

Expected: formatting completes successfully for the Rust workspace.
