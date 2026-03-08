# Compiled Source Coverage Checker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update `scripts/check-coverage.py` so it judges the runtime-bearing Rust source files actually compiled in the current `cargo llvm-cov` lane, with regression tests for the compiled-source contract.

**Architecture:** Extend the checker with two source-universe builders: a dep-info-based builder for the preferred path and a repository scan fallback for missing dep-info. Keep threshold handling and `--report-only` intact, and validate semantics through temporary-repo script tests.

**Tech Stack:** Python 3, `unittest`, `cargo llvm-cov` dep-info semantics, Rust source text heuristics

---

### Task 1: Capture the red tests in the isolated worktree

**Files:**
- Create: `scripts/tests/test_check_coverage.py`
- Modify: `scripts/check-coverage.py`

**Step 1: Write the failing tests**

Add regression tests for:

- compiled `src/**/*.rs` files missing from `coverage.json`
- `src/**/tests/*.rs` exclusion
- feature-gated compiled-source exclusion when absent from dep-info
- declaration-only compiled-source exclusion
- repo-relative dep-info resolution

**Step 2: Run the targeted tests to verify they fail**

Run: `python3 -m unittest tests.test_repo_settings_scripts`

Expected: unchanged existing tests pass, and the new coverage-checker tests fail until the script is updated.

**Step 3: Keep the test fixture style minimal**

- Use temporary directories.
- Copy the workspace script into the temp repo.
- Construct only the files needed for each case.

**Step 4: Commit the red tests**

```bash
git add scripts/tests/test_check_coverage.py
git commit -m "test: add coverage checker regression cases"
```

### Task 2: Implement dep-info-driven source discovery

**Files:**
- Modify: `scripts/check-coverage.py`
- Test: `scripts/tests/test_check_coverage.py`

**Step 1: Add the minimal helper functions**

Implement helpers for:

- runtime-bearing source detection
- repository scan fallback
- dep-info parsing
- expected source universe assembly

**Step 2: Update main coverage evaluation**

- Preserve `default`, `files`, and `exclude`.
- Preserve stdin vs path input handling.
- Preserve `--report-only`.
- Add compiled-but-missing files as failures with `0.0%`.

**Step 3: Run the new tests**

Run: `python3 scripts/tests/test_check_coverage.py`

Expected: PASS

**Step 4: Run a second pass against formatting and broader regressions**

Run: `python3 -m unittest tests.test_monitor_pr_checks`

Expected: PASS

**Step 5: Commit the implementation**

```bash
git add scripts/check-coverage.py scripts/tests/test_check_coverage.py
git commit -m "fix: check coverage against compiled runtime sources"
```

### Task 3: Verify the workspace contract end-to-end

**Files:**
- Verify: `scripts/check-coverage.py`
- Verify: `scripts/tests/test_check_coverage.py`

**Step 1: Run Rust workspace verification**

Run: `cargo fmt --all`

Expected: exit 0

**Step 2: Run lint verification**

Run: `cargo clippy --workspace`

Expected: exit 0

**Step 3: Run release tests**

Run: `cargo test --release --workspace`

Expected: exit 0

**Step 4: Run the Python regression suite**

Run: `python3 scripts/tests/test_check_coverage.py`

Expected: PASS

**Step 5: Commit verification-only follow-up if the implementation changed during cleanup**

```bash
git add scripts/check-coverage.py scripts/tests/test_check_coverage.py
git commit -m "chore: finalize coverage checker verification"
```

Only create this commit if verification required additional code changes.
