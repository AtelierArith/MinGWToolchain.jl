# AGENTS.md

Instructions for AI coding agents working in this repository.

## Project overview

`MinGWToolchain.jl` provides a lazily downloaded MinGW-w64 toolchain for
Windows x86_64. The package exposes artifact paths and compiler helpers
(`gcc`, `gxx`, `gfortran`, `ar`, `windres`, ...) plus `with_toolchain`.

The package itself must load on every platform. Unsupported platforms fail only
when a toolchain entry point such as `toolchain_root()` or `gcc()` is called,
not at module load time.

## Required workflow: PR first, merge only after CI passes

Never push commits directly to `main`. Every change goes through a pull request.

```sh
# 1. Start from an up-to-date main and create a topic branch
git switch main
git pull --ff-only
git switch -c <type>/<short-description>   # e.g. fix/docstring-interpolation

# 2. Make the change and run tests locally
julia --project=. -e 'using Pkg; Pkg.test()'

# 3. Push the branch and open a PR
git push -u origin <type>/<short-description>
gh pr create --base main --fill

# 4. Wait for CI
gh pr checks --watch

# 5. Merge only after every check has passed
gh pr merge --squash --delete-branch
```

Rules:

- Do not merge while any check is pending or failing.
- If CI fails, fix the problem on the same branch and push again. Do not merge
  a red PR and do not bypass checks.
- Do not force-push `main` or other shared branches.
- Do not commit build outputs, Julia depot contents, or downloaded artifacts.
- After merging, update local `main` with `git switch main && git pull --ff-only`.

## CI

The workflow is `.github/workflows/ci.yml`. It runs six jobs: Julia `1` and
`lts` on `windows-latest`, `ubuntu-latest`, and `macos-latest`. All six must
pass before merging. Windows jobs exercise the downloaded toolchain; the other
platforms only verify that the package loads and raises
`UnsupportedPlatformError` as expected.

## Testing

Run the package test suite with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

Windows integration tests compile and run C, C++, Fortran, and shared-library
samples. A C++ test may be skipped when Windows Application Control blocks
`cc1plus.exe`; this is an expected environment limitation, not a test failure.

## Implementation notes

- Keep platform checks inside functions (`_artifact_root`), never at module top
  level. A top-level failure prevents precompilation on macOS and Linux.
- Julia evaluates interpolation inside docstrings. In docstring examples that
  contain backtick commands, escape the dollar signs (`\$(gcc())`) or avoid
  interpolation entirely. An unescaped `$(gcc())` runs while the package loads.
- `__precompile__(false)` on Windows is intentional: unsigned precompile DLLs
  can be blocked by Application Control policies.
- `gcc()`, `gxx()`, and `gfortran()` prefer target-triple prefixed drivers
  (`x86_64-w64-mingw32-gcc.exe`, ...) because Application Control policies may
  block the short names. Keep that behavior.
- Use `Base.strip` in this package; `strip` is an exported tool name and
  shadows the `Base` function.
- Keep the `julia = "1.10"` compatibility bound in `Project.toml` unless the
  change explicitly requires a newer release.

## Pull request checklist

- [ ] The change is on a topic branch, not `main`.
- [ ] `Pkg.test()` passes locally (or the platform limitation is explained).
- [ ] All six CI jobs pass.
- [ ] The PR description states the problem, the fix, and how it was verified.
- [ ] The PR is merged with `--squash --delete-branch`.
