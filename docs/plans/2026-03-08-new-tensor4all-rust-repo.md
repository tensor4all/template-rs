# New Tensor4all Rust Repo Bootstrap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a home-global `new-tensor4all-rust-repo` bootstrap workflow that creates a repository from `template-rs`, installs initial project-local agent assets, and verifies the baseline without duplicating operations in `README.md`.

**Architecture:** Keep the bootstrap workflow outside generated repositories as a home-level skill. The skill delegates deterministic shell work to scripts, uses `gh` for remote operations, and leaves the generated repository with project-local commands plus vendored agent assets for normal day-to-day development.

**Tech Stack:** Markdown skills, Bash scripts, GitHub CLI, Rust workspace tooling, existing `template-rs` agent-assets bundle

---

### Task 1: Define the bootstrap skill surface

**Files:**
- Create: `ai/new-tensor4all-rust-repo/SKILL.md`
- Create: `ai/new-tensor4all-rust-repo/agents/openai.yaml`
- Reference: `docs/plans/2026-03-08-new-tensor4all-rust-repo-design.md`

**Step 1: Write the skill frontmatter and trigger language**

Add `name: new-tensor4all-rust-repo` and a description that triggers on requests to create or bootstrap a new tensor4all Rust repository from `template-rs`.

**Step 2: Write the skill workflow body**

Document:

- required inputs
- preflight checks
- remote creation and clone flow
- initial agent asset install
- verification commands
- failure reporting and rollback policy

**Step 3: Generate the UI metadata**

Create `agents/openai.yaml` from the final `SKILL.md` content so the skill appears correctly in supported UIs.

**Step 4: Validate the skill structure**

Run the local skill validation command used in the Codex skill environment.
Expected: the skill is recognized and metadata is consistent.

**Step 5: Commit**

```bash
git add ai/new-tensor4all-rust-repo/SKILL.md ai/new-tensor4all-rust-repo/agents/openai.yaml
git commit -m "feat: add new repo bootstrap skill scaffold"
```

### Task 2: Add deterministic bootstrap script support

**Files:**
- Create: `ai/new-tensor4all-rust-repo/scripts/new-repo.sh`
- Reference: `ai/scripts/check-agent-assets.sh`
- Reference: `ai/scripts/sync-agent-assets.sh`

**Step 1: Write a dry-run oriented shell interface**

Implement a script interface that accepts:

- repo name
- description
- optional org
- optional visibility
- optional destination path
- optional `--rollback-on-failure`

**Step 2: Add preflight checks**

Use `gh auth status`, `gh repo view`, filesystem checks, and upstream accessibility checks before creating the repository.

**Step 3: Add remote creation and clone logic**

Use `gh repo create <org>/<repo> --template tensor4all/template-rs` and `gh repo clone` with explicit error handling.

**Step 4: Add structured failure reporting**

Emit clear messages for:

- preflight failure
- remote created but clone failed
- clone succeeded but bootstrap failed

**Step 5: Smoke-test the script help path**

Run: `bash ai/new-tensor4all-rust-repo/scripts/new-repo.sh --help`
Expected: usage text describes inputs and safety flags.

**Step 6: Commit**

```bash
git add ai/new-tensor4all-rust-repo/scripts/new-repo.sh
git commit -m "feat: add deterministic bootstrap script"
```

### Task 3: Wire initial repository customization

**Files:**
- Modify: `ai/new-tensor4all-rust-repo/scripts/new-repo.sh`
- Modify: `README.md`

**Step 1: Add minimal metadata customization**

Patch the generated repository to apply the provided short description and any template placeholder replacements that are safe and clearly defined.

**Step 2: Add the README bootstrap section**

Insert the approved `AI Bootstrap` section into `README.md`:

```md
## AI Bootstrap

Create new repositories from this template with the home-global `new-tensor4all-rust-repo` skill.
After bootstrap, use the project-local `createpr`, `check-agent-assets`, and `sync-agent-assets` workflows.
This README intentionally does not duplicate the operational steps defined by those skills.
```

**Step 3: Verify the README remains concise**

Check that `README.md` points to skills without reproducing command-level procedures.

**Step 4: Commit**

```bash
git add README.md ai/new-tensor4all-rust-repo/scripts/new-repo.sh
git commit -m "docs: point template readme at bootstrap skill"
```

### Task 4: Install initial project-local agent assets in new repositories

**Files:**
- Modify: `ai/new-tensor4all-rust-repo/scripts/new-repo.sh`
- Reference: `ai/manifest.json`
- Reference: `ai/scripts/sync-agent-assets.sh`

**Step 1: Reuse the agent-asset sync mechanism**

After clone, invoke the project-local sync flow in the new repository so it receives:

- `ai/vendor/template-rs/*`
- `.claude/commands/*`
- `scripts/create-pr.sh`
- `scripts/check-agent-assets.sh`
- `scripts/sync-agent-assets.sh`
- `ai/agent-assets.lock`

**Step 2: Refuse silent overwrite**

Guard against overwriting managed assets if the initial repository state differs from expectation.

**Step 3: Verify the installed files exist**

Run targeted checks such as:

```bash
test -f .claude/commands/createpr.md
test -f ai/agent-assets.lock
test -f ai/vendor/template-rs/common-agent-rules.md
```

Expected: all managed assets are present after bootstrap.

**Step 4: Commit**

```bash
git add ai/new-tensor4all-rust-repo/scripts/new-repo.sh
git commit -m "feat: sync agent assets during repo bootstrap"
```

### Task 5: Add baseline verification to the bootstrap workflow

**Files:**
- Modify: `ai/new-tensor4all-rust-repo/scripts/new-repo.sh`
- Reference: `coverage-thresholds.json`
- Reference: `scripts/check-coverage.py`

**Step 1: Run the baseline checks in the generated repository**

Execute:

```bash
cargo fmt --all --check
cargo test --workspace
cargo llvm-cov --workspace --json --output-path coverage.json
python3 scripts/check-coverage.py coverage.json
cargo doc --no-deps
```

**Step 2: Preserve partial-success state**

If verification fails, keep the repository and print a structured summary that bootstrap completed but verification failed.

**Step 3: Add `--skip-verify` only if there is a demonstrated need**

Do not add a bypass flag unless real bootstrap usage shows the verification cost is too high.

**Step 4: Commit**

```bash
git add ai/new-tensor4all-rust-repo/scripts/new-repo.sh
git commit -m "feat: verify new repos after bootstrap"
```

### Task 6: Validate the bootstrap flow manually

**Files:**
- Test: `ai/new-tensor4all-rust-repo/SKILL.md`
- Test: `ai/new-tensor4all-rust-repo/scripts/new-repo.sh`
- Test: `README.md`

**Step 1: Run a dry bootstrap against a disposable repository name**

Use a throwaway test repository in a safe org or namespace and confirm preflight, remote creation, clone, sync, and verify behavior.

**Step 2: Inspect the resulting repository layout**

Confirm the generated repository contains:

- README bootstrap note
- project-local commands
- vendored common rules
- lockfile metadata

**Step 3: Exercise one downstream command**

Run the generated repo's `check-agent-assets` flow to confirm the bootstrap produced a coherent baseline.

**Step 4: Capture any script or docs fixes**

Patch rough edges found during manual validation and rerun the bootstrap until the flow is consistent.

**Step 5: Commit**

```bash
git add ai/new-tensor4all-rust-repo README.md
git commit -m "test: validate new repo bootstrap flow"
```
