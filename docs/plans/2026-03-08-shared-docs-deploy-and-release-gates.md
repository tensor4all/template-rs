# Shared Docs Deploy And Release Gates Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move docs-site deployment and stricter PR verification into `template-rs`, then resync `tenferro-rs`.

**Architecture:** Keep shared behavior in `template-rs` assets and workflows. Add a docs-site build/completeness check that derives crate coverage from the workspace instead of relying on hand-maintained links alone. Then resync the managed assets into `tenferro-rs` and fix repo-specific docs index content.

**Tech Stack:** Bash, Python 3, Cargo, GitHub Actions, `gh`

---

### Task 1: Update shared verification and docs-site tooling in `template-rs`

**Files:**
- Modify: `.github/workflows/ci.yml`
- Create: `.github/workflows/docs.yml`
- Create: `scripts/build-docs-site.sh`
- Create: `scripts/check-docs-site.py`
- Modify: `scripts/create-pr.sh`
- Modify: `ai/pr-workflow-rules.md`
- Modify: `ai/manifest.json`
- Modify: `README.md`

**Step 1:** Add release-mode workspace test checks and docs-site checks to the shared PR workflow.

**Step 2:** Add a shared docs deploy workflow and docs-site build/check scripts.

**Step 3:** Extend the managed asset manifest so sync can bring the shared workflows and docs scripts into downstream repos.

**Step 4:** Update template README instructions to document the shared docs deploy workflow.

### Task 2: Verify and push `template-rs`

**Files:**
- Verify only

**Step 1:** Run shell syntax checks on the new/updated scripts.

**Step 2:** Run workspace verification commands in `template-rs`.

**Step 3:** Commit and push directly to `origin/main`.

### Task 3: Resync `tenferro-rs` and fix repo-specific docs index gaps

**Files:**
- Modify: `docs/api_index.md`
- Modify: `ai/repo-settings.local.json`
- Sync managed files from `template-rs`

**Step 1:** Sync the latest managed assets from `template-rs`.

**Step 2:** Update `docs/api_index.md` so every workspace library crate appears in the generated docs-site landing page.

**Step 3:** Adjust repo-specific required status-check names if the shared workflow names changed.

### Task 4: Verify, push, and open the `tenferro-rs` PR

**Files:**
- Verify and git metadata only

**Step 1:** Run the full release-mode PR verification set in `tenferro-rs`.

**Step 2:** Commit the sync/update changes.

**Step 3:** Push the branch and create the PR with the repo-local workflow script.
