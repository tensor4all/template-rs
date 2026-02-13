# Agent Guidelines for Rust Projects

Read `README.md` before starting work.

## General Guidelines

- Use same language as past conversations (Japanese if previous was Japanese)
- Source code and docs in English
- **Bug fixing**: When a bug is discovered, always check related files for similar bugs and propose to the user to inspect them

## Context-Efficient Exploration

- Use Task tool with `subagent_type=Explore` for open-ended exploration
- Use Grep for structure: `pub fn`, `impl.*for`, `^pub (struct|enum|type)`
- Read specific lines with `offset`/`limit` parameters

## Code Style

`cargo fmt` for formatting, `cargo clippy` for linting. Avoid `unwrap()`/`expect()` in library code.

**Always run `cargo fmt --all` before committing changes.**

## Error Handling

- `anyhow` for internal error handling and context
- `thiserror` for public API error types

## Testing

**Always use `--release` mode for tests** to enable optimizations and speed up trial-and-error cycles.

```bash
cargo test --release                    # Full suite
cargo test --release --test test_name   # Specific test
cargo test --release --workspace        # All crates
```

- Private functions: `#[cfg(test)]` module in source file
- Integration tests: `tests/` directory
- **Test tolerance changes**: When relaxing test tolerances (unit tests, codecov targets, etc.), always seek explicit user approval before making changes.

## API Design

Only make functions `pub` when truly public API.

### Layering and Maintainability

**Respect crate boundaries and abstraction layers.**

- **Never access low-level APIs or internal data structures from downstream crates.** Use high-level public methods instead of directly manipulating internal representations.
- **Use high-level APIs.** If downstream code needs low-level access, create appropriate high-level APIs rather than exposing internal details.

**This applies to both library code and test code.** Tests should also use public APIs to maintain consistency and reduce maintenance burden when internal representations change.

### Code Deduplication

- **Avoid duplicate test code.** Use macros, functions, or generic functions to share test logic.

## Git Workflow

**Never push/create PR without user approval.**

### Pre-PR Checks

Before creating a PR, always run these checks locally:

```bash
cargo fmt --all          # Format all code
cargo clippy --workspace # Check for common issues
cargo test --release --workspace   # Run all tests
```

**Coverage check (must pass before push):**

```bash
cargo llvm-cov --workspace --json --output-path coverage.json
python3 scripts/check-coverage.py coverage.json
```

This checks per-file line coverage against thresholds in `coverage-thresholds.json`. Files not listed use the `default` threshold.

| Change Type | Workflow |
|-------------|----------|
| Minor fixes | Branch + PR with auto-merge |
| Large features | Worktree + PR with auto-merge |

```bash
# Minor: branch workflow
git checkout -b fix-name && git add -A && git commit -m "msg"
cargo fmt --all && cargo clippy --workspace  # Lint before push
git push -u origin fix-name
gh pr create --base main --title "Title" --body "Desc"
gh pr merge --auto --squash --delete-branch

# Large: worktree workflow
git worktree add ../project-feature -b feature

# Check PR before update
gh pr view <NUM> --json state  # Never push to merged PR

# Monitor CI
gh pr checks <NUM>
gh run view <RUN_ID> --log-failed
```
