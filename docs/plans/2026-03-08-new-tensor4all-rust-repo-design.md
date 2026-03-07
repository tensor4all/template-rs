# New Tensor4all Rust Repo Bootstrap Design

## Goal

Provide a home-global bootstrap skill, `new-tensor4all-rust-repo`, that creates a new tensor4all numerical Rust repository from `template-rs` and leaves it in a ready-to-develop state without duplicating operational instructions in `README.md`.

## Scope

The bootstrap skill exists outside the generated repository. It is responsible for creating repositories from `template-rs`, cloning them locally, applying minimal initialization, installing the initial project-local agent assets, and verifying the generated repository baseline.

It is not responsible for day-to-day PR creation. Once the repository exists, project-local commands such as `createpr`, `check-agent-assets`, and `sync-agent-assets` take over.

## Why This Lives In Home

`new-tensor4all-rust-repo` runs before a target repository exists. That makes it a poor fit for project-local installation. The skill should live in the user's home-level AI tooling, while the generated repository receives only the project-local commands and vendored assets it needs after bootstrap.

## Source Of Truth

`template-rs` remains the source of truth for:

- template repository contents
- vendored common agent rules
- project-local command assets
- bootstrap scripts referenced by the generated repository

The home-global skill orchestrates creation from the upstream template, but the generated repository runs from local checked-in files after bootstrap.

## User Inputs

The bootstrap skill uses a minimal-input contract.

Required inputs:

- repository name
- short description

Optional inputs:

- organization
- visibility
- destination path
- explicit safety overrides

Everything else is derived from conventions:

- template source: `tensor4all/template-rs`
- baseline agent asset installation
- README bootstrap note
- local wrapper structure for `AGENTS.md` and `CLAUDE.md`
- standard verification commands

## Bootstrap Flow

Recommended execution order:

1. Run preflight checks
2. Create the remote repository from `tensor4all/template-rs` using `gh`
3. Clone the repository locally
4. Apply minimal repository customization
5. Install or sync the initial project-local agent assets
6. Confirm local wrapper files and README references are in place
7. Run baseline verification
8. Return the repository URL, clone path, and follow-up actions

The bootstrap flow intentionally stops short of PR creation. Initial commits and later PR workflows are delegated to normal project-local commands.

## Preflight Checks

Before creating the remote repository, the bootstrap skill must verify:

- `gh auth status` succeeds
- the destination repository name does not already exist
- the destination clone path is absent or empty
- upstream `template-rs` is accessible

Preflight should happen before any remote side effect when possible.

## Minimal Customization

The bootstrap step should update only the lowest-risk repository metadata:

- repository description
- README wording where the template name is too generic
- any initial package/workspace naming placeholders if the template contains them

It should not attempt heavy project-specific scaffolding. The point is to produce a clean starting point, not to overfit every new repository at creation time.

## README Policy

`template-rs/README.md` should mention the existence of the bootstrap skill, but it must not duplicate its operational steps. The README stays focused on what the template provides.

Recommended README section:

```md
## AI Bootstrap

Create new repositories from this template with the home-global `new-tensor4all-rust-repo` skill.
After bootstrap, use the project-local `createpr`, `check-agent-assets`, and `sync-agent-assets` workflows.
This README intentionally does not duplicate the operational steps defined by those skills.
```

## Agent Asset Relationship

The bootstrap skill performs the initial install or sync of project-local agent assets so the new repository begins with:

- vendored common rules under `ai/vendor/template-rs/`
- project-local slash commands
- project-local helper scripts
- `ai/agent-assets.lock`

The generated repository then maintains those assets with `check-agent-assets` and `sync-agent-assets`.

## Verification

The bootstrap skill should run the same baseline checks expected by project-local PR workflows:

```bash
cargo fmt --all --check
cargo test --workspace
cargo llvm-cov --workspace --json --output-path coverage.json
python3 scripts/check-coverage.py coverage.json
cargo doc --no-deps
```

Failures do not imply rollback by default. They indicate that the repository was created successfully but needs follow-up work before normal development continues.

## Failure Policy

Use a preflight-first, conservative-rollback policy.

- If preflight fails before remote creation, stop with no side effects.
- If remote creation succeeds but clone or bootstrap later fails, report partial success clearly.
- Do not delete the remote repository automatically on failure.
- Allow explicit rollback only through an opt-in flag such as `--rollback-on-failure`.

This preserves debuggability and avoids destructive surprises.

## Safety Guards

The bootstrap skill must refuse unsafe actions by default:

- no overwrite of a non-empty destination path
- no silent replacement of managed agent assets
- no hidden rollback of remote repositories
- no implicit PR creation

## Non-Goals

- project-specific crate scaffolding beyond minimal metadata
- automatic repo mutation after bootstrap without user intent
- replacing the project-local `createpr` workflow
- duplicating operational instructions across skill files and README files

## Recommended Next Step

Implement the home-global `new-tensor4all-rust-repo` skill and keep the generated repositories thin: README points to the skill, while operational logic lives in the skill and in project-local synced assets.
