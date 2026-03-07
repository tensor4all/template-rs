# template-rs

Template repository for Rust workspace projects in the tensor4all organization.

## What's included

- **Cargo workspace** — empty workspace ready to add crates
- **CI (GitHub Actions)** — fmt, test (ubuntu + macOS), coverage, doc
- **Coverage checking** — per-file line coverage thresholds via `cargo llvm-cov`
- **Agent assets** — shared rules, project-local commands, and repo workflow scripts
- **Bootstrap skill source** — `ai/new-tensor4all-rust-repo` for home-global installation

## Usage

1. Install the `new-tensor4all-rust-repo` bootstrap skill
2. Use that skill to create a new repository from this template
3. Add crates to `Cargo.toml` `members`
4. Adjust `coverage-thresholds.json` as needed

## AI Bootstrap

The preferred workflow is to install the home-global `new-tensor4all-rust-repo` skill and let it create new repositories from this template.
That bootstrap flow also enables GitHub auto-merge and protects the default branch with the full CI status-check set.

### Codex

```bash
TEMPLATE_RS=/path/to/template-rs
mkdir -p ~/.codex/skills
ln -s "$TEMPLATE_RS/ai/new-tensor4all-rust-repo" \
  ~/.codex/skills/new-tensor4all-rust-repo
```

### Claude Code

```bash
TEMPLATE_RS=/path/to/template-rs
mkdir -p ~/.claude/skills
ln -s "$TEMPLATE_RS/ai/new-tensor4all-rust-repo" \
  ~/.claude/skills/new-tensor4all-rust-repo
```

If you prefer copies over symlinks, copy the directory instead.

After bootstrap, generated repositories should contain:

- vendored shared rules under `ai/vendor/template-rs/`
- repo settings under `ai/repo-settings.json`
- repo-local workflow scripts under `scripts/`
- project-local Claude commands under `.claude/commands/`
- local wrappers `AGENTS.md` and `CLAUDE.md`

## Coverage

Coverage is checked per-file against thresholds in `coverage-thresholds.json`.

```bash
# Run locally
cargo llvm-cov --workspace --json --output-path coverage.json
python3 scripts/check-coverage.py coverage.json
```

To set a custom threshold for a specific file:

```json
{
  "default": 80,
  "files": {
    "src/hard_to_test.rs": 50
  }
}
```
