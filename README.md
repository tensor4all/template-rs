# template-rs

Template repository for Rust workspace projects in the tensor4all organization.

## What's included

- **Cargo workspace** — empty workspace ready to add crates
- **CI (GitHub Actions)** — fmt, test (ubuntu + macOS), coverage, doc
- **Coverage checking** — per-file line coverage thresholds via `cargo llvm-cov`
- **Agent guidelines** — CLAUDE.md / AGENTS.md for AI-assisted development

## Usage

1. Click **"Use this template"** on GitHub to create a new repository
2. Add crates to `Cargo.toml` `members`
3. Adjust `coverage-thresholds.json` as needed

## Coverage

Coverage is checked per-file against thresholds in `coverage-thresholds.json`.
Meet the configured threshold with meaningful tests rather than filler assertions, and keep each test quick to run.

```bash
# Run locally
cargo llvm-cov --workspace --json --output-path coverage.json
python3 scripts/check-coverage.py coverage.json
```

Set the repo-wide default in `coverage-thresholds.json`, and add per-file overrides under `files` only when justified.
