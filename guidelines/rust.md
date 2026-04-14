# Rust Language Guidelines

These rules apply to all Rust projects and are shared across `architect`, `developer`, and `code-reviewer` agents. They override general guidance on conflict.

## Crate Structure for Binary Projects

- A crate that ships a binary MUST also expose a library: put all real logic in `src/lib.rs` (and its module tree) and place binary entry points under `src/bin/<name>.rs`. Do NOT put logic in a top-level `src/main.rs`.
  - Reason: integration tests under `tests/` are compiled as separate crates and can only import the library crate's public API. A bare `src/main.rs` binary has no library to import, so integration tests cannot exercise it. Splitting into `src/lib.rs` + `src/bin/*.rs` makes the same logic reachable from both the binary and `tests/`.
- Each file under `src/bin/` should be a thin shim: parse arguments, build the composition root, call into the library, translate errors to exit codes. No business logic.
- For workspaces, the same rule applies per crate: any crate that would otherwise be binary-only gets a `lib.rs` sibling containing the logic.
- `code-reviewer` MUST flag business logic placed directly in `src/main.rs` or `src/bin/*.rs` (beyond the shim responsibilities above) as a 🔴 blocker.

## Test Layout

This section refines the Testing rules from the global `CLAUDE.md` for Rust. BDD with the Detroit (classicist) school of TDD still applies — test real collaborators, mock only at architectural boundaries, verify state and output rather than interactions.


- **Unit tests**: Co-located in the same file as the code under test, inside a `#[cfg(test)] mod tests { ... }` block. Scope is limited to the module's internals (including private items).
- **Integration tests**: MUST live under the crate's top-level `tests/` directory (Cargo's integration test convention). Each file in `tests/` is compiled as a separate crate and may only exercise the **public API** of the crate under test.
  - Do NOT place integration tests inside `src/` or inside `#[cfg(test)]` modules.
  - Do NOT test private items from integration tests — if coverage is missing, the API surface is wrong, not the test location.
  - Shared helpers for integration tests go under `tests/common/mod.rs` (not `tests/common.rs`, which would be compiled as its own test crate).
- **Doc tests**: Use for small, illustrative examples on public items. Do not rely on doc tests as the primary coverage mechanism.
- **End-to-end / black-box tests** that span multiple crates in a workspace belong in a dedicated `tests/` crate at the workspace root or in a separate `xtask`-style crate, never mixed into library `src/`.

`code-reviewer` MUST flag any integration test placed outside `tests/` as a 🔴 blocker.

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
- `pub` items require English docstrings (`///`). `pub(crate)` and narrower do not, but should still have clear names.
- Avoid re-exporting third-party types through your public API unless the dependency is intentionally part of your contract.

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
