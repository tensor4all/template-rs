# Nextest Rollout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `cargo nextest` the default test runner across the template's CI, repository settings, helper scripts, and coding rules while keeping doctests explicitly covered.

**Architecture:** Add a small regression test that validates the template's expected verification commands and required status-check names from repository files. Then update the workflow, settings, helper scripts, and rule documents together so the repository describes and executes one consistent testing strategy: `cargo nextest run` for normal tests, `cargo test --doc` for doctests, and `cargo llvm-cov nextest` for coverage.

**Tech Stack:** GitHub Actions YAML, Bash scripts, JSON, Markdown, Python `unittest`

---

### Task 1: Add regression coverage for the rollout

**Files:**
- Create: `scripts/tests/test_nextest_rollout.py`

**Step 1: Write the failing test**

Add a Python `unittest` module that reads repository files as text and asserts:
- `.github/workflows/ci.yml` contains a `nextest`-named test job, installs `cargo-nextest`, runs `cargo nextest run --workspace --release --no-fail-fast`, and runs `cargo test --doc --workspace --release`
- `ai/repo-settings.json` uses `nextest (ubuntu-latest)` and `nextest (macos-latest)` as required status checks
- `scripts/create-pr.sh` and `ai/new-tensor4all-rust-repo/scripts/new-repo.sh` mention the `nextest`/doctest verification commands

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest scripts.tests.test_nextest_rollout -v`
Expected: FAIL because the repository still references `cargo test` rather than `nextest`

**Step 3: Commit**

Do not commit yet; continue once the test is red.

### Task 2: Update execution paths to use nextest

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `ai/repo-settings.json`
- Modify: `scripts/create-pr.sh`
- Modify: `ai/new-tensor4all-rust-repo/scripts/new-repo.sh`

**Step 1: Write minimal implementation**

Update CI and helper scripts so they all use the same command set:
- install `cargo-nextest` where needed
- use `cargo nextest run --workspace --release --no-fail-fast` for standard test execution
- run `cargo test --doc --workspace --release` explicitly for doctests
- use `cargo llvm-cov nextest --workspace --release --json --output-path coverage.json` for coverage
- rename required status-check contexts to match the workflow job names

**Step 2: Run targeted regression test**

Run: `python3 -m unittest scripts.tests.test_nextest_rollout -v`
Expected: PASS

**Step 3: Run command-level verification**

Run:
- `cargo nextest run --workspace --release --no-fail-fast`
- `cargo test --doc --workspace --release`
- `cargo llvm-cov nextest --workspace --release --json --output-path coverage.json`
- `python3 scripts/check-coverage.py coverage.json`

Expected: all commands exit successfully

### Task 3: Update rule and template documentation

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `ai/numerical-rust-rules.md`
- Modify: `ai/pr-workflow-rules.md`

**Step 1: Write minimal implementation**

Replace `cargo test` examples with `cargo nextest run` where the guidance is about standard unit/integration test execution, and add an explicit note that doctests remain a separate `cargo test --doc` step.

**Step 2: Re-run the regression test**

Run: `python3 -m unittest scripts.tests.test_nextest_rollout -v`
Expected: PASS

**Step 3: Run full local verification**

Run:
- `cargo fmt --all`
- `cargo fmt --all --check`
- `cargo clippy --workspace`
- `python3 -m unittest scripts.tests.test_nextest_rollout -v`
- `cargo nextest run --workspace --release --no-fail-fast`
- `cargo test --doc --workspace --release`
- `cargo llvm-cov nextest --workspace --release --json --output-path coverage.json`
- `python3 scripts/check-coverage.py coverage.json`
- `cargo doc --workspace --no-deps`
- `python3 scripts/check-docs-site.py`

Expected: all commands pass

### Task 4: Commit, push, create PR, and enable auto-merge

**Files:**
- Modify: PR body generated from `scripts/create-pr.sh` or pass explicit body via `gh pr create`

**Step 1: Commit**

Run:
```bash
git add .github/workflows/ci.yml ai/repo-settings.json scripts/create-pr.sh ai/new-tensor4all-rust-repo/scripts/new-repo.sh AGENTS.md README.md ai/numerical-rust-rules.md ai/pr-workflow-rules.md scripts/tests/test_nextest_rollout.py docs/plans/2026-03-11-nextest-rollout-implementation.md
git commit -m "ci: adopt nextest across template workflows"
```

**Step 2: Push and create PR**

Run:
```bash
git push -u origin rules/nextest-template
gh pr create --base main --title "ci: adopt nextest across template workflows" --body-file <prepared-body>
gh pr merge --auto --squash --delete-branch
```

**Step 3: Monitor CI**

Run: `bash scripts/monitor-pr-checks.sh <pr-url-or-number> --interval 30`
Expected: all required checks pass; auto-merge completes
