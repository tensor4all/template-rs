# Compiled Source Coverage Checker Design

## Context

`scripts/check-coverage.py` should validate the Rust source files that were actually compiled in the current `cargo llvm-cov` lane, not every `src/**/*.rs` file that exists in the repository and not only the files already present in `coverage.json`.

Issue #3 asks for the semantics already proven in downstream `tenferro-rs`, while preserving template-local threshold configuration and the existing `--report-only` surface.

## Goals

- Prefer dep-info from `target/llvm-cov-target/**/*.d` to derive the expected source universe.
- Judge only runtime-bearing `src/**/*.rs` files that were compiled in the current lane.
- Ignore module-local unit test sources under `src/**/tests/*.rs`.
- Ignore declaration-only compiled Rust files that carry no runtime code.
- Fall back to a repository scan only when dep-info is unavailable.
- Preserve `default`, `files`, `exclude`, and `--report-only`.

## Non-Goals

- Raising default thresholds.
- Adding downstream repo-specific smoke tests.
- Changing CI policy or coverage thresholds outside the checker contract.

## Approach Options

### Option 1: Coverage JSON only

Use only entries already present in `coverage.json` and keep threshold evaluation as-is.

- Pros: smallest implementation.
- Cons: cannot detect compiled source files omitted from the coverage report, which is the actual bug.

### Option 2: Dep-info first, repository scan fallback

Parse `target/llvm-cov-target/**/*.d` to discover compiled `.rs` files, filter them to runtime-bearing `src/**/*.rs`, and fall back to scanning the repo only when dep-info is unavailable.

- Pros: matches the desired contract, supports feature-gated lanes, and keeps local coverage aligned with the built lane.
- Cons: requires lightweight Rust source classification logic.

### Option 3: Always full repository scan

Ignore dep-info and scan the repository for `src/**/*.rs` files, then heuristically drop declarations and module-local tests.

- Pros: simpler than dep-info parsing.
- Cons: incorrectly includes feature-gated files not compiled in the current lane.

## Decision

Use Option 2.

This is the only option that satisfies the issue requirements without broadening the source universe beyond the current `cargo llvm-cov` lane.

## Data Flow

1. Load thresholds from `coverage-thresholds.json`.
2. Read coverage JSON from stdin or the first positional path, while preserving `--report-only`.
3. Build the expected source universe:
   - Parse dep-info files when available.
   - Resolve dep-info paths against both the dep-info parent directory and the repository root.
   - Keep only compiled `src/**/*.rs` files.
   - Exclude `src/**/tests/*.rs`.
   - Exclude declaration-only files with no runtime-bearing code.
   - Fall back to repository scan when dep-info yields no files.
4. Compare expected files against `coverage.json` entries, still honoring `exclude`.
5. Report threshold failures plus compiled-but-missing files.

## Runtime-Bearing Heuristic

The checker needs a narrow heuristic instead of a full Rust parser.

- Treat functions with bodies as runtime-bearing.
- Treat `const` or `static` items initialized with block expressions as runtime-bearing.
- Treat declaration-only items such as traits, structs, enums, and function signatures ending in `;` as non-runtime-bearing.
- Allow multi-line function signatures by buffering until either `{` or `;` appears.

This is intentionally conservative: it should avoid false positives for declaration-only modules while still catching compiled executable code.

## Testing Strategy

Add script tests covering:

- failing when a compiled `src/**/*.rs` file is absent from `coverage.json`
- ignoring `src/<module>/tests/*.rs`
- ignoring feature-gated files not compiled in the current lane
- ignoring declaration-only compiled files
- resolving repo-relative dep-info paths

The tests should build temporary repositories around the script so the semantics are validated without depending on the workspace layout.

## Risks

- Dep-info files may contain relative paths from different working directories.
  Mitigation: resolve against both the dep-info file location and repo root.
- The runtime heuristic may misclassify unusual Rust constructs.
  Mitigation: keep the heuristic minimal and behavior-focused, matching the issue requirements only.
