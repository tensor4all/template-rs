# Agentic Bug Sweep Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a bounded headless Codex workflow that runs `agentic-tests`, triages findings against existing GitHub issues, creates or consolidates issues, records related same-root-cause issues, and stops after either a configured iteration count or too many consecutive `none` results.

**Architecture:** Keep deterministic control flow in a Bash entrypoint under `scripts/`, keep Codex reasoning in a fixed prompt under `ai/`, and enforce the handoff with a checked-in JSON schema. Store durable reports under `docs/test-reports/agentic-bug-sweep/` and ephemeral execution state under `target/agentic-bug-sweep/`.

**Tech Stack:** Bash, JSON Schema, GitHub CLI, headless `codex exec`, Python `unittest`, existing repository `ai/` and `scripts/` conventions

---

### Task 1: Add the prompt and schema surfaces

**Files:**
- Create: `ai/agentic-bug-sweep.md`
- Create: `ai/agentic-bug-sweep.schema.json`
- Create: `tests/test_agentic_bug_sweep.py`
- Reference: `docs/plans/2026-03-08-agentic-bug-sweep-design.md`

**Step 1: Write the failing test**

Add a `unittest` case that asserts:

- `ai/agentic-bug-sweep.md` exists and instructs Codex to inspect open issues and prior reports
- `ai/agentic-bug-sweep.schema.json` parses as JSON
- the schema recognizes `create`, `update`, `merge`, and `none`
- the schema contains `related_issue_numbers` support for same-root-cause findings

**Step 2: Run the test to verify it fails**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_prompt_and_schema_contract -v`
Expected: FAIL because the prompt, schema, and test file do not yet exist.

**Step 3: Write the minimal prompt and schema**

Implement the fixed prompt and the JSON schema with conditional requirements for each action.

**Step 4: Run the test to verify it passes**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_prompt_and_schema_contract -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add ai/agentic-bug-sweep.md ai/agentic-bug-sweep.schema.json tests/test_agentic_bug_sweep.py
git commit -m "feat: add agentic bug sweep prompt contract"
```

### Task 2: Scaffold the shell entrypoint

**Files:**
- Create: `scripts/agentic-bug-sweep.sh`
- Modify: `tests/test_agentic_bug_sweep.py`
- Reference: `scripts/create-pr.sh`

**Step 1: Write the failing help-path test**

Add a `unittest` case that runs `bash scripts/agentic-bug-sweep.sh --help` in a temp repo fixture and asserts the usage text mentions:

- `--iterations`
- `--max-consecutive-none`
- `--repo`
- `--workdir`

**Step 2: Run the test to verify it fails**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_help_path -v`
Expected: FAIL because the script does not exist yet.

**Step 3: Add the CLI surface**

Implement argument parsing, preflight checks, and state-directory creation in `scripts/agentic-bug-sweep.sh`.

**Step 4: Run the test to verify it passes**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_help_path -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add scripts/agentic-bug-sweep.sh tests/test_agentic_bug_sweep.py
git commit -m "feat: scaffold agentic bug sweep entrypoint"
```

### Task 3: Implement one iteration of headless Codex execution

**Files:**
- Modify: `scripts/agentic-bug-sweep.sh`
- Modify: `tests/test_agentic_bug_sweep.py`

**Step 1: Write the failing test for a single successful iteration**

Add a `unittest` case that stubs `codex exec` to emit a valid `action=create` payload and asserts that the shell script records the iteration output in the expected directories.

**Step 2: Run the test to verify it fails**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_single_iteration_create -v`
Expected: FAIL because the script does not yet invoke `codex exec` or persist iteration output.

**Step 3: Add minimal Codex invocation**

Implement one iteration that:

- builds a context payload from open issues and prior reports
- calls `codex exec` with the fixed prompt and schema
- saves raw output and parsed JSON to `target/agentic-bug-sweep/output/`

**Step 4: Run the test to verify it passes**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_single_iteration_create -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add scripts/agentic-bug-sweep.sh tests/test_agentic_bug_sweep.py
git commit -m "feat: run one headless codex bug sweep iteration"
```

### Task 4: Implement GitHub mutation branches

**Files:**
- Modify: `scripts/agentic-bug-sweep.sh`
- Modify: `tests/test_agentic_bug_sweep.py`

**Step 1: Write failing tests for `create`, `update`, `merge`, `none`, and related-issue recording**

Add tests that stub:

- `gh issue create` for `create`
- `gh issue comment` for `update`
- canonical comment plus duplicate comment and close ordering for `merge`
- related issue comments or body linking for same-root-cause findings
- no `gh` mutation for `none`

**Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_github_actions -v`
Expected: FAIL because the mutation branches are incomplete.

**Step 3: Implement the mutation helpers**

Add Bash helpers that:

- create a new issue from title, body, and labels
- comment on an existing issue
- comment on duplicates and close them after the canonical issue update
- record and optionally comment on `related_issue_numbers` for same-root-cause findings
- skip GitHub mutation entirely for `none`

**Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_github_actions -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add scripts/agentic-bug-sweep.sh tests/test_agentic_bug_sweep.py
git commit -m "feat: apply github actions for bug sweep outcomes"
```

### Task 5: Implement iteration bookkeeping and stop conditions

**Files:**
- Modify: `scripts/agentic-bug-sweep.sh`
- Modify: `tests/test_agentic_bug_sweep.py`

**Step 1: Write failing tests for loop control**

Add tests that verify:

- the script never exceeds `--iterations`
- `action=none` increments the dry-run counter
- `create`, `update`, and `merge` reset the dry-run counter
- the script stops early after `--max-consecutive-none`

**Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_stop_conditions -v`
Expected: FAIL because loop control and reset behavior are incomplete.

**Step 3: Implement the loop and counters**

Track:

- current iteration number
- current consecutive-`none` count
- final stop reason

Persist a small summary artifact for each run.

**Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_stop_conditions -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add scripts/agentic-bug-sweep.sh tests/test_agentic_bug_sweep.py
git commit -m "feat: add bounded loop control to bug sweep"
```

### Task 6: Harden failure handling and audit artifacts

**Files:**
- Modify: `scripts/agentic-bug-sweep.sh`
- Modify: `tests/test_agentic_bug_sweep.py`

**Step 1: Write failing tests for hard failures**

Add tests for:

- failed `codex exec`
- invalid JSON output
- failed `gh` mutation after a valid report
- lock acquisition failure

**Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_failure_paths -v`
Expected: FAIL because the error handling and audit artifacts are incomplete.

**Step 3: Implement conservative failure behavior**

Ensure the script:

- exits non-zero on the first hard failure
- preserves raw Codex output on invalid JSON
- preserves report references after partial success
- records the stop reason clearly

**Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_agentic_bug_sweep.AgenticBugSweepTests.test_failure_paths -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add scripts/agentic-bug-sweep.sh tests/test_agentic_bug_sweep.py
git commit -m "feat: preserve audit state on bug sweep failures"
```

### Task 7: Document usage and repository expectations

**Files:**
- Modify: `README.md`
- Reference: `AGENTS.md`
- Reference: `docs/plans/2026-03-08-agentic-bug-sweep-design.md`

**Step 1: Add a short automation note to the README**

Document:

- the purpose of `scripts/agentic-bug-sweep.sh`
- the required tools (`codex`, `gh`)
- the bounded iteration model
- where reports and logs are stored

Keep the README concise and avoid duplicating the full prompt logic.

**Step 2: Verify the README remains high-level**

Check that the README points readers to the script and generated artifacts without re-embedding the internal JSON contract.

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add agentic bug sweep usage note"
```

### Task 8: Run full verification

**Files:**
- Test: `scripts/agentic-bug-sweep.sh`
- Test: `tests/test_agentic_bug_sweep.py`
- Test: `ai/agentic-bug-sweep.md`
- Test: `ai/agentic-bug-sweep.schema.json`

**Step 1: Run formatter and tests**

Run:

```bash
cargo fmt --all
python3 -m unittest tests.test_agentic_bug_sweep -v
```

Expected: formatting succeeds and the bug sweep tests pass.

**Step 2: Run the broader Python test suite**

Run:

```bash
python3 -m unittest tests.test_create_pr_script tests.test_monitor_pr_checks tests.test_repo_settings_scripts tests.test_new_repo_script tests.test_agentic_bug_sweep -v
```

Expected: existing script tests still pass with the new automation files present.

**Step 3: Run a help-path smoke test**

Run:

```bash
bash scripts/agentic-bug-sweep.sh --help
```

Expected: usage text prints successfully.

**Step 4: Commit**

```bash
git add README.md scripts/agentic-bug-sweep.sh tests/test_agentic_bug_sweep.py ai/agentic-bug-sweep.md ai/agentic-bug-sweep.schema.json
git commit -m "test: verify agentic bug sweep workflow"
```
