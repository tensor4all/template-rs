# template-rs

Template repository for Rust workspace projects in the tensor4all organization.

## What's included

- **Cargo workspace** — empty workspace ready to add crates
- **CI (GitHub Actions)** — fmt, nextest + doctest (ubuntu + macOS), coverage, doc
- **Coverage checking** — per-file line coverage thresholds via `cargo llvm-cov`
- **Agent guidelines** — CLAUDE.md / AGENTS.md for AI-assisted development

## Usage

1. Click **"Use this template"** on GitHub to create a new repository
2. Add crates to `Cargo.toml` `members`
3. Adjust `coverage-thresholds.json` as needed

## Agentic Bug Sweep

Use `bash scripts/agentic-bug-sweep.sh` to run a bounded headless Codex bug sweep that can create, update, or consolidate GitHub issues.

Requirements:

- `codex`
- `gh`

Primary mode is remote-repository analysis:

```bash
bash scripts/agentic-bug-sweep.sh \
  --repo-url https://github.com/tensor4all/tenferro-rs \
  --ref main \
  --iterations 20 \
  --max-consecutive-none 3
```

`--workdir` remains available as a local override when you already have a checked-out repository.

The workflow always stops after the configured `--iterations` limit or after `--max-consecutive-none` dry runs in a row.

Artifacts:

- durable reports: `docs/test-reports/agentic-bug-sweep/`
- ephemeral execution state: `target/agentic-bug-sweep/`

## Testing

Run unit and integration tests with nextest, and keep doctests as a separate step:

```bash
cargo nextest run --workspace --release --no-fail-fast
cargo test --doc --workspace --release
```

## Coverage

Coverage is checked per-file against thresholds in `coverage-thresholds.json`.
Meet the configured threshold with meaningful tests rather than filler assertions, and keep each test quick to run.

```bash
# Run locally
cargo llvm-cov nextest --workspace --release --json --output-path coverage.json
python3 scripts/check-coverage.py coverage.json
```

Set the repo-wide default in `coverage-thresholds.json`, and add per-file overrides under `files` only when justified.
