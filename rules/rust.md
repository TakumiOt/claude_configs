---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Makefile.toml"
---

# Rust Language Guidelines

These rules apply to all Rust projects and are shared across `architect`, `developer`, and `code-reviewer` agents. They auto-load when Claude touches Rust source or Cargo / Makefile.toml files. They override general guidance on conflict.

## Crate Structure

Rust projects in this team use a Cargo **workspace split by bounded context**. The full crate-level layout (which crates exist, the dependency graph, the workspace-level review checklist) lives in `~/.claude/rules/architecture.md` "Directory and Crate Structure" — this section covers only the Rust-level mechanics that apply per crate.

### Per-crate rules

- **Library by default**: every workspace crate exposes a `src/lib.rs`. Domain crates, `shared-kernel`, `infrastructure`, the test-support libraries under `crates/test-*/`, and the test-runner crates under `tests/<name>/` are library-only and have no `src/main.rs` or `src/bin/*.rs`.
- **Binaries live in `app` only**: only the `app` crate ships executables. Place each binary entry point under `app/src/bin/<name>.rs` and keep the file as a thin shim — parse arguments, build the composition root by calling into `app`'s library, translate errors to exit codes. No business logic.
  - Reason: integration tests are compiled as separate crates and can only import the library crates' public APIs. A bare `src/main.rs` binary has no library to import, so the test harness cannot exercise it. Splitting `app` into `app/src/lib.rs` + `app/src/bin/*.rs` makes the composition root reachable from both the binary and the test-runner crates under `tests/<name>/`.
- **Workspace-root `Cargo.toml`** is a virtual workspace: it declares `[workspace]` with the crate `members` list and shared `[workspace.dependencies]` / `[workspace.package]`, but no `[package]` of its own.

`code-reviewer` MUST flag the following as 🔴 blockers:

- Business logic placed directly in `app/src/main.rs` or `app/src/bin/*.rs` beyond the shim responsibilities above.
- A binary entry point (`main.rs` / `bin/*.rs`) added to any crate other than `app`.
- Logic placed in the workspace-root `Cargo.toml`'s `[package]` section (the root must remain a virtual workspace).

## Test Layout

This section refines the Testing rules from the global `CLAUDE.md` for Rust. BDD with the Detroit (classicist) school of TDD still applies — test real collaborators, mock only at architectural boundaries, verify state and output rather than interactions.

### Layout (workspace + test-runner crates under `tests/<name>/`)

- **Unit tests**: Co-located in the same file as the code under test, inside a `#[cfg(test)] mod tests { ... }` block. Scope is limited to the module's internals, including private items. Lives **inside the same crate** as the code under test (typically a domain crate, `shared-kernel`, or `infrastructure`).
- **Integration tests and E2E tests**: ALL integration and end-to-end tests live in test-runner crates under the workspace-root `tests/<name>/` directory (typical runners are `tests/integration/` for HTTP-level wiring, `tests/usecase/` for use-case branch coverage against a real database, and `tests/infrastructure/` for infrastructure-adapter branch coverage against a real database). Each `.rs` file under `tests/<name>/tests/` is compiled as a separate test binary and may exercise the public APIs of the domain crates, the `infrastructure` crate, and the `app` crate via injected ports / composition.
  - The phrase "`tests/` directory" is ambiguous on its own — it refers to **two different things** in this rule: the workspace-root `tests/` directory (which IS the home for test-runner crates and is required) versus a `tests/` directory inside any individual crate (which is forbidden outside the test-runner crates' own `tests/<name>/tests/`).
  - Do NOT create a `tests/` directory inside any `crates/<production>/` crate (domain crates, `shared-kernel`, `infrastructure`, `app`) or inside any `crates/test-*/` test-support library. Those crates have unit tests only. The only allowed `tests/` directories are the test-runner crates' own `tests/<name>/tests/` (Cargo's per-crate integration-test directory inside the runner).
  - Do NOT place integration tests inside `src/` or inside `#[cfg(test)]` modules.
  - Do NOT test private items from integration tests — if coverage is missing, the API surface is wrong, not the test location.
  - Shared helpers (DB setup, fixtures, builders, test-only HTTP clients) live in `tests/<name>/src/lib.rs` (the runner crate's library entry). Each test file imports them with `use <runner_crate>::...;` (e.g. `use test_integration::...;` when the runner crate's `[package].name` is `"test-integration"`). The legacy `tests/common/mod.rs` pattern is not used here — the runner crate's own `lib.rs` already provides a stable home for helpers.
- **Test-support library naming**: Test-support **library** crates under `crates/` (e.g. a contract-test helper library or a shared DB-fixture library) MUST use the `test-*` prefix (`test-contract`, `test-db`, ...). The shared prefix keeps these libraries grouped together in alphabetical `crates/` listings and signals their non-production role at a glance. Test-runner crates under `tests/<name>/` do NOT require the prefix — the `tests/` directory itself already groups them and signals their role; the runner crate's `[package].name` may follow either convention (e.g. `"test-integration"` is acceptable, so is `"tests-integration"` if a new runner is named afresh).
- **Doc tests**: Use for small, illustrative examples on public items. Do not rely on doc tests as the primary coverage mechanism.

### Why test-runner crates live under `tests/<name>/`

- **Physical grouping of test concerns**: each test-runner crate addresses a distinct test concern (HTTP-level integration in `tests/integration/`, use-case-level real-DB testing in `tests/usecase/`, infrastructure-adapter real-DB testing in `tests/infrastructure/`). Placing them under a shared `tests/` directory groups them at the directory level so a reader can scan `tests/<name>/` to enumerate all test-runner crates without reading `Cargo.toml`.
- **`crates/` stays focused on code**: production crates and test-support libraries live under `crates/`. Test-runner crates live under `tests/`. The split keeps `crates/` listings free of test-runner noise and makes the "production vs. test-execution" boundary visible in the directory tree.
- **Cross-domain scenarios** have a natural home in `tests/integration/`: the runner crate is the only place that depends on multiple domain crates plus `infrastructure` and `app`, so end-to-end flows across bounded contexts can be exercised without violating the inter-domain "no direct dependency" rule at the production layer.
- **Real persistence / HTTP-client implementations** live in `infrastructure`. Concentrating tests that wire `infrastructure` against domain ports in the test-runner crates keeps DB setup / teardown, transaction management, and fixture loading in one place per runner.
- Cargo compiles every file under `tests/<name>/tests/` as a separate test binary, so test-binary parallelism is preserved while shared helpers stay in a single library per runner.

`code-reviewer` MUST flag any of the following as 🔴 blockers:

- An integration / E2E test placed anywhere outside the test-runner crates under `tests/<name>/`.
- A `tests/` directory created inside any `crates/<production>/` crate or any `crates/test-*/` test-support library (the only allowed `tests/` directories are the test-runner crates' own `tests/<name>/tests/`).

## Task Runner

- Use `cargo make` as the project-standard task runner. Do NOT invoke bare `cargo test` / `cargo build` / `cargo clippy` when a `Makefile.toml` exists.
- Typical tasks: `cargo make test`, `cargo make lint`, `cargo make build`. Check the project's `Makefile.toml` for the exact task names before running.

## Domain Modeling — Newtype Pattern

- Wrap primitive types with newtypes for all domain identifiers and value objects: `struct UserId(Uuid)`, `struct Email(String)`, `struct Money { amount: i64, currency: Currency }`. Do NOT pass raw `String` / `Uuid` / `i64` across use case boundaries when they represent a domain concept.
- Enforce invariants in the constructor: `Email::new(s: &str) -> Result<Self, DomainError>`. Keep the inner field private so invalid states are unrepresentable.
- Derive `Debug`, `Clone`, `PartialEq`, `Eq`, `Hash` as needed. Derive `Copy` only for cheap value types.
- This prevents primitive obsession and makes the domain model self-documenting at the type level.

## Serde and Framework Boundaries

- `#[derive(Serialize, Deserialize)]` belongs on **adapter-layer DTOs only** (HTTP request/response types, database row structs, message queue payloads). Never derive serde on domain entities, value objects, or use case input/output types.
- Adapters are responsible for mapping DTO ⇄ domain type. This mapping is the boundary where validation and newtype construction happen.
- The same rule applies to other framework-specific derives (`sqlx::FromRow`, `ToSchema` for OpenAPI, ORM macros, etc.) — they stay in the outer layers.
- `code-reviewer` MUST flag serde derives on domain types as a 🔴 blocker (framework leakage into inner layers).

## Time and Clock Injection

- Never call `std::time::SystemTime::now()`, `chrono::Utc::now()`, or `tokio::time::Instant::now()` directly from the domain or use case layer. Doing so makes the code non-deterministic and untestable.
- Define a `Clock` port (trait) in the use case layer with a method like `now(&self) -> DateTime<Utc>`. Inject it like any other dependency.
- Provide a real implementation in the infrastructure layer (`SystemClock`) and a controllable test double (`FixedClock` / `MockClock`) for tests.
- The same rule applies to other sources of non-determinism: random number generation (`Rng` port), UUID generation (`IdGenerator` port), etc.

## Panic Policy

- Library code (anything not in `main.rs` / `bin/*.rs`) MUST NOT contain `.unwrap()` or `.expect("...")` on fallible operations. Return a `Result` instead.
- The only acceptable `.expect("...")` uses are on operations that are provably infallible given surrounding invariants (e.g. a regex compiled from a `const` literal). The expect message MUST explain *why* the call cannot fail — not what the code does.
- `todo!()`, `unimplemented!()`, `panic!("not yet")`, and `unreachable!()` without a proof comment MUST NOT be committed. `unreachable!()` is acceptable when paired with a comment explaining the invariant that guarantees unreachability.
- `.unwrap()` is acceptable in test code (`#[cfg(test)]`) where a panic is an intentional test failure signal.

## Error Handling

- Define domain error types as enums with `thiserror::Error` in the Entities / Use Cases layer.
- At layer boundaries, convert infrastructure errors (`sqlx::Error`, `reqwest::Error`, `std::io::Error`, etc.) into domain errors. Never let them leak inward.
- Use `Result<T, DomainError>` in use case signatures. Reserve `anyhow::Error` for the outermost binary / adapter layer only — never in library crates' public APIs.
- Prefer `?` over manual `match` for propagation. Use `.map_err(...)` at boundaries to perform the conversion.

## Visibility and API Surface

- Default to the narrowest visibility: private → `pub(crate)` → `pub(super)` → `pub`. Widen only when a real caller needs it.
- `pub` items require English docstrings — see "Docstrings (Rust overlay)" below for the exact section layout.
- Avoid re-exporting third-party types through your public API unless the dependency is intentionally part of your contract.

## Docstrings (Rust overlay)

This section maps the general rules in `~/.claude/rules/docstrings.md` onto Rust's idiomatic doc-comment conventions. On conflict with `docstrings.md`, this section wins for `.rs` files; the underlying "Summary / Why / Contract / Side effects / Example" requirements still apply.

### Comment style

- `///` documents the item that follows. Use it for `pub` functions, methods, structs, enums, unions, traits, type aliases, and constants.
- `//!` is an inner doc comment. Use it for module-level docs (top of `mod.rs` / `<module>.rs`) and crate-level docs (top of `src/lib.rs`).
- The `//!` overview is the home for the module's big picture and any Why shared by several items — write it like a Rust std library module page, then keep each item's `///` short (see `docstrings.md` "Module-Level Docstrings" and "Where Each Why Lives").
- Place doc comments directly above the item — no blank line between the comment and the item.
- Implementation-mechanic rationale (why a derive, why zero-sized, why error detail is dropped at a boundary) goes in ordinary `//` body comments next to the code — not in the `///` doc comment, which states the caller-facing contract.

### Section heading layout

Rustdoc uses standard `#`-headed sections. Layer the general docstring structure onto them as follows. Headings inside a doc comment use a single `#` at the line start (`# Examples`, `# Errors`, ...).

| General item (from `docstrings.md`) | Rust placement |
|---|---|
| 1. Summary (one line) | First line of the doc comment, terminated by a blank line. Reused as the search-result snippet — keep it concise. |
| 2. Why / Responsibility | One or two sentences after the summary, before any `#`-headed section. Why shared by several items goes in the module `//!`; implementation-mechanic Why goes in `//` body comments — not the doc comment (see `docstrings.md` "Where Each Why Lives"). |
| 3. Contract — parameters and return | Bulleted list when 2+ parameters need explanation; a single sentence otherwise. Add `# Arguments` / `# Returns` headings only when the contract is non-trivial. |
| 3. Contract — error variants | `# Errors` section. **Required** whenever the function returns `Result`. List the domain error variants and the conditions that trigger each. |
| 3. Contract — panic conditions | `# Panics` section. **Required** whenever the function may panic, including a non-trivial `.expect("...")` and panics from a violated precondition. |
| 4. Side effects | Surface in the Why / detail area when present (I/O, state mutation, external call, blocking, async cancellation behavior). State "Pure" when none. |
| 5. Example | `# Examples` section with a runnable doc test in a ` ```rust ` fenced block. **Required** on traits and on `pub` functions whose intended usage is non-obvious. |
| Unsafe contract | `# Safety` section. **Required** for every `unsafe fn` and `unsafe trait`, listing the invariants the caller must uphold. |

### Intra-doc links

- Reference other items via intra-doc link syntax: `` [`UserId`] ``, `` [`Repository::find`] ``, `` [`crate::shared_kernel::Email`] ``. Do not hand-construct URLs to docs.rs or relative HTML paths — they break on rename and across crate versions.
- Enable `#![warn(rustdoc::broken_intra_doc_links)]` at the crate root so dangling links surface during `cargo make lint`, not only at `cargo doc` time.

### Doc-test discipline

- ` ```rust ` blocks (the default) are compiled and run by `cargo make test`. Keep them green — they are part of the test suite, not decoration.
- Use `no_run` only when the example performs real I/O the test environment cannot satisfy (network, filesystem, database). Use `ignore` only with an inline comment stating the reason.
- Do not hide non-trivial setup behind `# `-prefixed lines. The visible portion of the example must reflect realistic usage so readers can copy-paste it into their own crate.

### Port traits

- Trait-level `///`: describe the abstract domain contract — what the port promises to the use case layer — without naming the infrastructure backing it.
- Method-level `///`: the `# Errors` section MUST list **domain** error variants (`UserNotFound`, `EmailAlreadyTaken`, ...). Infrastructure error types (`sqlx::Error`, `reqwest::Error`, `std::io::Error`) MUST NOT appear in port docstrings — they are converted at the adapter boundary.
- `# Examples` on a port trait should reference an in-memory or fake implementation, not the real infrastructure adapter, so the example documents the contract rather than a particular adapter.

### Lint enforcement

- Enable `#![warn(missing_docs)]` at the crate root of every library crate so the compiler enforces docstring presence on `pub` items. `cargo make lint` MUST remain green with this lint active.

`code-reviewer` MUST apply the following severities in addition to the matrix in `docstrings.md`:

- A `pub` function returning `Result` without an `# Errors` section → 🔴 blocker.
- A function that may panic (including a non-trivial `.expect("...")`) without a `# Panics` section → 🔴 blocker.
- An `unsafe fn` or `unsafe trait` without a `# Safety` section → 🔴 blocker.
- A port-trait method's `# Errors` section that names infrastructure error types instead of domain variants → 🔴 blocker (counts as "infrastructure leakage into the inner layer").
- Hand-constructed URLs to other items instead of intra-doc links → 🟡 suggestion.
- A doc test marked `ignore` without an inline reason → 🟡 suggestion.
- An `# Examples` block on a port trait that wires real infrastructure rather than a fake → 🟡 suggestion.

## Async

- Pick one runtime per crate (typically `tokio`) and stick to it. Do not mix `async-std` and `tokio` in the same dependency tree.
- Traits with async methods: prefer `async fn` in traits (stable since Rust 1.75) over `async-trait` unless object-safety is required.
- Do not block the async runtime with `std::thread::sleep`, synchronous file I/O, or CPU-heavy work — use `tokio::time::sleep`, `tokio::fs`, or `spawn_blocking` respectively.

## Clippy and Lints

- `cargo make lint` must pass with zero warnings. Treat `clippy::pedantic` findings as suggestions, not blockers, unless the project opts in.
- Do not `#[allow(...)]` lints silently. Every allow requires a one-line comment explaining why.

## Logging and Observability

- Use the `tracing` crate as the single logging/observability facade. Do NOT mix `log`, `println!`, `eprintln!`, or ad-hoc `dbg!` in committed code.
- Emit **structured fields**, not interpolated strings: `tracing::info!(user_id = %id, "user logged in")` — not `tracing::info!("user {} logged in", id)`. Fields are queryable; interpolated messages are not.
- **Layer discipline**: domain and use case layers MUST NOT emit log records. They return `Result<T, DomainError>`; the adapter / infrastructure layer decides how to log failures and successes. This keeps inner layers deterministic and framework-free.
- Use `#[tracing::instrument(...)]` on adapter / infra entry points to get automatic span coverage. Skip large or sensitive fields with `skip` / `skip_all`.
- Choose levels deliberately: `error` for failed operations a human must investigate, `warn` for recoverable anomalies, `info` for state transitions, `debug` for development detail, `trace` for hot-path diagnostics. Default production filter is `info`.
- Never log secrets, credentials, full PII, or raw request bodies. Redact at the adapter boundary.

## Dependency Hygiene

- Any new crate added to `Cargo.toml` requires the Dependency Approval Process from the global CLAUDE.md. No silent additions.
- Prefer the standard library and existing dependencies over pulling in new ones.
- **Always use the latest released version.** Before adding a dependency, check the current version on crates.io (`cargo search <name>` or `cargo add <name>` which resolves to latest) — do NOT copy an older version from memory or another project.
- **Version specifier format: `"xx.yy"` (major.minor only).** Example: `serde = "1.0"`, `tokio = "1.38"`. Do NOT write exact patches (`"1.38.0"`), caret prefixes (`"^1.38"`), tildes (`"~1.38"`), wildcards (`"*"`), or git dependencies. Cargo's default semver behavior on `"xx.yy"` already allows compatible patch and minor updates.
- When bumping a dependency, update to the latest major.minor and record the reason in the PR description if the bump crosses a major version.
- `code-reviewer` MUST flag version specifiers that include patch numbers, wildcards, git refs, or that are known to be outdated (a newer minor exists on crates.io) as a 🟡 suggestion.
