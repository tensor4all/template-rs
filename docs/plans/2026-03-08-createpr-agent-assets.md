# CreatePR And Agent Assets Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add reusable agent asset bundle files and project-local PR workflow commands to `template-rs` for tensor4all numerical Rust projects.

**Architecture:** Keep common policy in `template-rs/ai/` as upstream source-of-truth, publish a manifest for managed assets, vendor those assets into generated repositories, and expose project-local slash commands backed by repo-local shell scripts. `createpr` is the policy-enforcing workflow command; `check-agent-assets` and `sync-agent-assets` manage freshness and synchronization.

**Tech Stack:** Markdown command files, Bash scripts, `gh` CLI, existing Rust workspace/coverage tooling.

---

### Task 1: Create Shared AI Asset Layout

**Files:**
- Create: `ai/common-agent-rules.md`
- Create: `ai/numerical-rust-rules.md`
- Create: `ai/pr-workflow-rules.md`
- Create: `ai/manifest.json`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

**Step 1: Draft common rules files**

Write the shared rules extracted from the approved design:

- `common-agent-rules.md`
- `numerical-rust-rules.md`
- `pr-workflow-rules.md`

**Step 2: Add initial manifest**

Create `ai/manifest.json` with placeholders for:

- source repo
- source ref
- bundle revision
- managed asset paths

**Step 3: Convert wrappers to thin loaders**

Update `AGENTS.md` and `CLAUDE.md` so they:

- remain project-local wrappers
- reference the shared `ai/*.md` files
- leave room for downstream project-specific additions

**Step 4: Review structure**

Run:

```bash
find ai -maxdepth 2 -type f | sort
```

Expected: the four new `ai/` files exist and wrapper files still exist.

**Step 5: Commit**

```bash
git add AGENTS.md CLAUDE.md ai
git commit -m "feat: add shared AI rule bundle layout"
```

### Task 2: Add Project-Local Claude Commands

**Files:**
- Create: `.claude/commands/createpr.md`
- Create: `.claude/commands/check-agent-assets.md`
- Create: `.claude/commands/sync-agent-assets.md`

**Step 1: Write `check-agent-assets` command**

Create a slash command that:

- announces read-only update checking
- calls the repo-local `scripts/check-agent-assets.sh`
- explains quiet/default behavior

**Step 2: Write `sync-agent-assets` command**

Create a slash command that:

- calls `scripts/sync-agent-assets.sh`
- explains overwrite protection and `--force`

**Step 3: Write `createpr` command**

Create a slash command that:

- re-reads local rules before PR creation
- calls `scripts/create-pr.sh`
- documents `--allow-stale`

**Step 4: Review command wording**

Run:

```bash
sed -n '1,200p' .claude/commands/createpr.md
sed -n '1,200p' .claude/commands/check-agent-assets.md
sed -n '1,200p' .claude/commands/sync-agent-assets.md
```

Expected: each command is explicit about its single responsibility.

**Step 5: Commit**

```bash
git add .claude/commands
git commit -m "feat: add AI workflow slash commands"
```

### Task 3: Implement Update Check Script

**Files:**
- Create: `scripts/check-agent-assets.sh`
- Create: `ai/agent-assets.example.lock`
- Modify: `ai/manifest.json`

**Step 1: Write a failing smoke check**

Add an example lock file and manually exercise the script contract:

- missing lock
- manifest fetch failure
- matching revision
- stale revision

Document expected shell exit codes in comments at the top of the script.

**Step 2: Implement minimal script**

Implement `scripts/check-agent-assets.sh` to:

- read local lock if present
- fetch manifest with `gh`
- compare revisions
- support `--quiet`

**Step 3: Verify local behavior**

Run:

```bash
bash scripts/check-agent-assets.sh --help
```

Expected: usage text shows quiet mode and exit semantics.

**Step 4: Verify stale path with fixture**

Run the script against a fixture or temporary file path and confirm it reports `update-available`.

**Step 5: Commit**

```bash
git add scripts/check-agent-assets.sh ai/manifest.json ai/agent-assets.example.lock
git commit -m "feat: add agent asset freshness check"
```

### Task 4: Implement Sync Script

**Files:**
- Create: `scripts/sync-agent-assets.sh`
- Modify: `ai/manifest.json`

**Step 1: Define managed asset list**

Ensure the manifest includes all assets that sync should manage:

- shared rule files
- slash commands
- local scripts

**Step 2: Implement protected sync**

Implement `scripts/sync-agent-assets.sh` to:

- fetch the manifest and assets using `gh`
- write vendored files
- update lock metadata
- refuse overwrite on local modifications unless `--force`

**Step 3: Verify dry behavior**

Run:

```bash
bash scripts/sync-agent-assets.sh --help
```

Expected: help text explains managed files and overwrite behavior.

**Step 4: Manually test local modification detection**

Create a temporary managed file mismatch and confirm the script stops without `--force`.

**Step 5: Commit**

```bash
git add scripts/sync-agent-assets.sh ai/manifest.json
git commit -m "feat: add agent asset sync workflow"
```

### Task 5: Implement PR Creation Script

**Files:**
- Create: `scripts/create-pr.sh`
- Modify: `ai/pr-workflow-rules.md`
- Modify: `README.md`

**Step 1: Encode required preflight**

Document the ordered checks in `ai/pr-workflow-rules.md` and mirror them in the script:

- `check-agent-assets --quiet`
- stale handling with `--allow-stale`
- local rule reload
- docs gate
- format/test/coverage/doc checks
- PR body generation
- `gh pr create`
- optional auto-merge

**Step 2: Implement minimal happy-path script**

Implement `scripts/create-pr.sh` with:

- argument parsing
- temp file body generation
- `gh pr create`
- optional `gh pr merge --auto --squash --delete-branch`

**Step 3: Verify help and command ordering**

Run:

```bash
bash scripts/create-pr.sh --help
```

Expected: help text lists stale handling and required checks.

**Step 4: Review documentation**

Update `README.md` to explain:

- the three commands
- manifest/lock concept
- how downstream repos consume them

**Step 5: Commit**

```bash
git add scripts/create-pr.sh ai/pr-workflow-rules.md README.md
git commit -m "feat: add PR creation workflow script"
```

### Task 6: Add Template Defaults For Coverage And Docs Gates

**Files:**
- Modify: `coverage-thresholds.json`
- Modify: `scripts/check-coverage.py`
- Modify: `.github/workflows/ci.yml`
- Modify: `README.md`

**Step 1: Verify required defaults already exist**

Inspect whether the template already includes:

- `coverage-thresholds.json`
- `scripts/check-coverage.py`
- doc generation in CI

**Step 2: Add missing defaults**

If any are missing, add them so generated repositories satisfy the shared PR workflow contract.

**Step 3: Verify local commands in docs**

Ensure `README.md` shows:

```bash
cargo llvm-cov --workspace --json --output-path coverage.json
python3 scripts/check-coverage.py coverage.json
cargo doc --no-deps
```

**Step 4: Run template verification**

Run:

```bash
cargo fmt --all --check
cargo test --workspace
cargo llvm-cov --workspace --json --output-path coverage.json
python3 scripts/check-coverage.py coverage.json
cargo doc --no-deps
```

Expected: all commands complete successfully in the template repository.

**Step 5: Commit**

```bash
git add coverage-thresholds.json scripts/check-coverage.py .github/workflows/ci.yml README.md
git commit -m "feat: align template defaults with PR workflow gates"
```

### Task 7: Validate End-To-End Bundle Consumption

**Files:**
- Modify: `README.md`
- Test: generated throwaway repo from the template

**Step 1: Create a throwaway downstream repo from local files**

Use a temporary directory to mimic a generated project and copy the managed assets into it.

**Step 2: Run `check-agent-assets` in the throwaway repo**

Expected: it can read the local lock and report status cleanly.

**Step 3: Run `sync-agent-assets --help` and `createpr --help`**

Expected: both commands explain their guarded workflows clearly.

**Step 4: Document downstream usage**

Update `README.md` with the exact downstream setup and sync story.

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: explain downstream AI asset consumption"
```
