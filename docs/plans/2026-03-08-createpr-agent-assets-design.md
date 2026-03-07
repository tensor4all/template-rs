# CreatePR And Agent Assets Design

## Goal

Provide a reusable, project-local AI workflow bundle for tensor4all numerical Rust projects, sourced from `template-rs`, with:

- project-local slash commands for PR creation and agent asset maintenance
- vendored common agent rules and command assets in each working repository
- explicit upstream sync instead of runtime self-mutation
- PR gating that re-reads local rules and enforces documentation, test, coverage, and PR policy checks

## Scope

The bundle contains three user-facing commands:

- `createpr`
- `check-agent-assets`
- `sync-agent-assets`

The bundle supports Claude Code directly via project-local slash commands. Codex support uses the same vendored assets and scripts, with a thin adapter layer added later. The canonical behavior is shared across agents.

## Source Of Truth

`template-rs` is the upstream source of truth for common agent assets. Runtime behavior must never depend on a live network fetch. Repositories use local vendored copies. Network access is only used for update checking and explicit sync.

Common reusable rules are split out of the wrapper `AGENTS.md` into dedicated files under `ai/`.

## File Layout

Upstream in `template-rs`:

```text
ai/
├── manifest.json
├── common-agent-rules.md
├── numerical-rust-rules.md
├── pr-workflow-rules.md
├── claude/
│   └── commands/
│       ├── createpr.md
│       ├── check-agent-assets.md
│       └── sync-agent-assets.md
└── scripts/
    ├── create-pr.sh
    ├── check-agent-assets.sh
    └── sync-agent-assets.sh
```

Downstream in each generated repository:

```text
AGENTS.md
CLAUDE.md
ai/
├── agent-assets.lock
└── vendor/
    └── template-rs/
        ├── common-agent-rules.md
        ├── numerical-rust-rules.md
        └── pr-workflow-rules.md
.claude/
└── commands/
    ├── createpr.md
    ├── check-agent-assets.md
    └── sync-agent-assets.md
scripts/
├── create-pr.sh
├── check-agent-assets.sh
└── sync-agent-assets.sh
```

`AGENTS.md` and `CLAUDE.md` remain thin project-local wrappers. They are not overwritten during sync.

## Wrapper Rule Strategy

The wrapper files contain:

- local project-specific instructions
- ordered references to vendored common rule files
- metadata pointing to the synced upstream revision

The common reusable text lives in vendored markdown files, not inline remote URLs. This avoids offline degradation and keeps repo-local diffs reviewable.

## Agent Asset Metadata

The upstream bundle publishes `ai/manifest.json` with:

- source repository identity
- source ref
- bundle revision
- asset list and relative paths
- optional content hashes

Each downstream repo records the currently synced state in `ai/agent-assets.lock` with:

- synced upstream repo and ref
- synced bundle revision
- timestamp
- local asset paths
- local hashes for overwrite detection

`stale` means the downstream lock revision is older than the upstream bundle revision.

## Command Responsibilities

### `check-agent-assets`

Read-only command.

- reads local `ai/agent-assets.lock`
- fetches upstream `ai/manifest.json` using `gh`
- compares bundle revisions
- optionally compares local file hashes with the lock
- returns one of:
  - `up-to-date`
  - `update-available`
  - `unable-to-check`

`--quiet` prints nothing when up to date.

### `sync-agent-assets`

Explicit update command.

- fetches upstream manifest and listed assets using `gh`
- updates vendored common rule files, project-local slash commands, and local scripts
- rewrites `ai/agent-assets.lock`
- refuses to overwrite locally modified managed assets unless `--force` is supplied

It does not rewrite project-local wrapper `AGENTS.md` or `CLAUDE.md`.

### `createpr`

PR workflow command with mandatory preflight.

Execution order:

1. Run `check-agent-assets --quiet`
2. If assets are stale, warn and require explicit `--allow-stale` to continue
3. Re-read local `AGENTS.md` and related vendored workflow rules
4. Resolve PR policy from local rules
5. Run git preflight checks
6. Run docs consistency gate
7. Run format, test, coverage, and doc checks
8. Compose PR title/body
9. Create the PR with `gh pr create`
10. Enable auto-merge when local rules require it

`createpr` uses a temporary body file rather than inline shell heredocs.

## Documentation Consistency Gate

`createpr` always runs a documentation gate, even when code changes appear unrelated.

The gate covers:

- `README.md`
- `docs/design/**`
- public API rustdoc comments
- `cargo doc --no-deps`

The gate is intentionally lighter than semantic proof. It enforces that the relevant surfaces are reviewed and blocks PR creation when required documentation is clearly missing or broken.

## Checks Required By Default

For tensor4all numerical Rust projects generated from `template-rs`, the reusable PR workflow requires:

```bash
cargo fmt --all --check
cargo test --workspace
cargo llvm-cov --workspace --json --output-path coverage.json
python3 scripts/check-coverage.py coverage.json
cargo doc --no-deps
```

`template-rs` is updated to include `coverage-thresholds.json` and `scripts/check-coverage.py` by default.

## What Moves To Template-RS

From `tenferro-rs`, the reusable rule base should absorb:

- documentation requirements
- file organization rules
- unit test organization rules
- ASCII diagram conventions
- workspace dependency rules
- generic numerical Rust testing guidance
- PR creation and auto-merge rules
- coverage and docs consistency policy
- agent asset sync policy

Repository-specific architecture, tensor layout conventions, and crate-specific commands remain local.

## Non-Goals

- automatic runtime mutation of local instruction files
- mandatory network access during normal execution
- repo-specific architectural guidance in the shared bundle
- silent overwrite of locally edited managed assets

## Recommended Next Step

Implement the shared `ai/` bundle in `template-rs`, then wire the generated repositories to consume vendored copies through explicit sync commands.
