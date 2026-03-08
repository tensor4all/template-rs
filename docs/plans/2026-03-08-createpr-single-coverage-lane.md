# CreatePR Single Coverage Lane Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Change the shared local PR workflow so `createpr` uses a single release-mode `cargo llvm-cov` lane instead of running both plain release tests and coverage tests.

**Architecture:** Keep CI unchanged, update only the local PR workflow surfaces, and prove the script behavior with a focused temp-repo test around `scripts/create-pr.sh`.

**Tech Stack:** Bash, Python `unittest`, fake CLI fixtures for `git`/`cargo`/`gh`

---

### Task 1: Add a failing script test for `create-pr.sh`

**Files:**
- Create: `tests/test_create_pr_script.py`
- Modify: `scripts/create-pr.sh`

**Step 1: Write the failing test**

Create a temp repository fixture that copies `scripts/create-pr.sh` and stubs:

- `scripts/check-agent-assets.sh`
- `scripts/check-repo-settings.sh`
- `scripts/monitor-pr-checks.sh`
- `scripts/check-docs-site.py`

Provide fake `git`, `cargo`, and `gh` binaries that log invocations.

**Step 2: Assert the intended behavior**

The test must prove:

- `cargo test --workspace --release` is not invoked
- `cargo llvm-cov --workspace --release --json --output-path coverage.json` is invoked
- the generated PR body lists the updated verification commands

**Step 3: Run the new test to verify it fails**

Run: `python3 -m unittest tests.test_create_pr_script`

Expected: FAIL because the current script still runs `cargo test --workspace --release` and omits `--release` from `cargo llvm-cov`.

### Task 2: Update the shared local PR workflow

**Files:**
- Modify: `scripts/create-pr.sh`
- Modify: `ai/pr-workflow-rules.md`
- Modify: `.claude/commands/createpr.md`
- Test: `tests/test_create_pr_script.py`

**Step 1: Update `scripts/create-pr.sh`**

- Remove the plain local `cargo test --workspace --release` call from `run_required_checks`
- Change the coverage invocation to `cargo llvm-cov --workspace --release --json --output-path coverage.json`
- Update the generated PR body verification list to match

**Step 2: Update the shared docs**

- Change `ai/pr-workflow-rules.md` to describe the new local PR verification sequence
- Clarify in `.claude/commands/createpr.md` that the script remains the source of truth for checks

**Step 3: Run the focused script test**

Run: `python3 -m unittest tests.test_create_pr_script`

Expected: PASS

### Task 3: Verify repository-wide behavior

**Files:**
- Verify: `scripts/create-pr.sh`
- Verify: `tests/test_create_pr_script.py`

**Step 1: Run formatting**

Run: `cargo fmt --all`

Expected: exit 0

**Step 2: Run linting**

Run: `cargo clippy --workspace`

Expected: exit 0

**Step 3: Run release tests**

Run: `cargo test --release --workspace`

Expected: exit 0

**Step 4: Run the new script regression test**

Run: `python3 -m unittest tests.test_create_pr_script`

Expected: PASS

**Step 5: Commit the implementation**

```bash
git add scripts/create-pr.sh ai/pr-workflow-rules.md .claude/commands/createpr.md tests/test_create_pr_script.py
git commit -m "fix: remove duplicate local createpr test lane"
```
