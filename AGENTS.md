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

## Dependencies

**Use workspace dependencies for libraries shared across multiple crates** to keep versions consistent. Define the dependency once in the workspace `Cargo.toml` under `[workspace.dependencies]`, then reference it with `dep.workspace = true` in each crate's `Cargo.toml`.

## Error Handling

- `anyhow` for internal error handling and context
- `thiserror` for public API error types
- Use `assert!` with informative messages for programming invariants (invalid shapes, dimension mismatches)

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

### Keeping Tests Fast

- **Use small data sizes.** 2x2, 2x3 matrices are sufficient for correctness tests. Random tests should use dimensions 1-3.
- **Hardcode test data** when possible for full reproducibility. When randomized tests are needed, use seeded RNG (`StdRng::seed_from_u64`) and limit iteration counts.
- **Sample large arrays** instead of checking every element. Use `step_by()` to spot-check when testing parallelization thresholds.
- **Feature-gate expensive tests.** Put optional algebra or backend tests behind `#[cfg(feature = "...")]`.

### Generic Tests — Avoid Type Duplication

Write test logic once for multiple scalar types (f64, Complex64) using these patterns:

**Pattern 1: `scalar_tests!` macro** — generates `_f64` and `_c64` test variants from a generic function:

```rust
// Define generic test
fn test_operation_generic<T: Scalar>() {
    // ... test logic works for any T
}

// Generate concrete tests (uses `paste` crate)
macro_rules! scalar_tests {
    ($name:ident, $test_fn:ident) => {
        paste::paste! {
            #[test]
            fn [<$name _f64>]() { $test_fn::<f64>(); }
            #[test]
            fn [<$name _c64>]() { $test_fn::<Complex64>(); }
        }
    };
}
scalar_tests!(test_operation, test_operation_generic);
```

**Pattern 2: `TestScalar` trait** — for polymorphic test data generation:

```rust
pub trait TestScalar: Scalar + From<f64> {
    fn make_test_data(size: usize) -> Vec<Self>;
}
impl TestScalar for f64 {
    fn make_test_data(size: usize) -> Vec<Self> {
        (0..size).map(|i| (i + 1) as f64).collect()
    }
}
impl TestScalar for Complex64 {
    fn make_test_data(size: usize) -> Vec<Self> {
        (0..size).map(|i| Complex64::new((i + 1) as f64, (i as f64) * 0.1)).collect()
    }
}

// Generic builder — one function, both types
pub fn make_tensor_generic<T: TestScalar>(dims: &[usize]) -> Tensor<T> {
    let size: usize = dims.iter().product();
    Tensor::from_data(&T::make_test_data(size), dims)
}
```

**Pattern 3: Type-erased enum** — when f64 and Complex64 must coexist at runtime:

```rust
pub enum Operand { F64(Data<f64>), C64(Data<Complex64>) }
```

### Test Helpers and Assertions

- **Centralize custom assertions** (e.g., `assert_tensors_approx_equal`) to avoid duplicating tolerance logic.
- **Use higher-order helpers** like `for_each_index(dims, |idx| { ... })` to eliminate nested loops.
- **Parameterize over algorithms**: test multiple algorithms with the same validation helper.

```rust
fn test_factorize_reconstruction(options: &FactorizeOptions) {
    let tensor = create_test_matrix();
    let result = factorize(&tensor, &left_inds, options).unwrap();
    let reconstructed = result.left.contract(&result.right);
    assert_tensors_approx_equal(&tensor, &reconstructed, 1e-10);
}

#[test]
fn test_all_algorithms() {
    for alg in [SVD, QR, LU] {
        test_factorize_reconstruction(&FactorizeOptions { alg, .. });
    }
}
```

## API Design

Only make functions `pub` when truly public API.

### Trait Design

- Define a common `Scalar` trait with `f64` and `Complex64` implementations to write generic library code once.
- Use `#[inline]` on small trait method implementations.
- Use associated types (`type Scalar`, `type Index`) instead of extra generic parameters where possible.
- Prefer default method implementations to reduce boilerplate for implementors.

### Layering and Maintainability

**Respect crate boundaries and abstraction layers.**

- **Never access low-level APIs or internal data structures from downstream crates.** Use high-level public methods instead of directly manipulating internal representations.
- **Use high-level APIs.** If downstream code needs low-level access, create appropriate high-level APIs rather than exposing internal details.

**This applies to both library code and test code.** Tests should also use public APIs to maintain consistency and reduce maintenance burden when internal representations change.

### Code Deduplication

- **Macros for repetitive impls.** Use `impl_for_type!` macros when the same trait impl differs only by type:

```rust
macro_rules! impl_for_type {
    ($($t:ty),*) => { $(impl MyTrait for $t { /* ... */ })* };
}
impl_for_type!(f32, f64, Complex32, Complex64);
```

- **Avoid duplicate test code.** Use macros, generic functions, or parameterized helpers to share test logic.

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
