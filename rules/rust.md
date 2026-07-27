---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Makefile.toml"
---

# Rust Language Guidelines

These rules apply to all Rust projects and are shared across `architect`, `developer`, and `code-reviewer` agents. They auto-load when Claude touches Rust source or Cargo / Makefile.toml files. They override general guidance on conflict.

Division of labor with `~/.claude/rules/architecture.md`: **layer responsibilities, port placement, and layer-boundary review observations** live there; **everything physical and Rust-specific** — workspace / crate structure, DI mechanics, ownership at boundaries, Axum boundary rules, and all per-crate mechanics — lives here.

## Directory and Crate Structure

Rust projects MUST use a Cargo workspace, split **by bounded context (domain)** rather than by Clean Architecture layer. Splitting by domain keeps related business rules cohesive within one crate so a reader can follow a domain end-to-end without crate hopping; technical concerns (DB, external IO) are concentrated in a separate `infrastructure` crate. Layered splits at workspace level (`entity` / `usecase` / `adapter` crates) are NOT used in this project.

### Workspace layout (project default)

```text
Cargo.toml                         # workspace root: declares [workspace] members (no [package])
crates/                            # production code + test-support libraries
├── shared-kernel/
│   ├── Cargo.toml                 # [package] no workspace dependencies
│   └── src/lib.rs                 # cross-cutting value objects and ports (Clock, Money, Email, etc.)
├── <domain-a>/                    # bounded context A (e.g. user, order, payment)
│   ├── Cargo.toml                 # [package] dependencies = shared-kernel only
│   └── src/
│       ├── lib.rs
│       ├── entity/                # entities, value objects, repository ports, domain errors
│       ├── usecase/               # use cases, input/output DTOs, gateway / query-service ports
│       └── adapter/               # controllers, presenters, request/response DTOs
├── <domain-b>/
│   ├── Cargo.toml
│   └── src/{lib.rs, entity/, usecase/, adapter/}
├── infrastructure/                # technical concerns concentrated here
│   ├── Cargo.toml                 # dependencies = every domain crate + shared-kernel
│   └── src/
│       ├── lib.rs
│       ├── persistence/           # DB connection pool, migrations, shared query helpers
│       ├── repository/            # implementations of every domain crate's repository port
│       ├── http_client/           # external API clients (gateway implementations)
│       └── messaging/             # message queue, event bus
├── app/                           # composition root (binary)
│   ├── Cargo.toml                 # depends on every crate above
│   └── src/{lib.rs, bin/<name>.rs}
├── test-db/                       # test-support library (library-only)
│   ├── Cargo.toml                 # depends on infrastructure + domain crates as needed
│   └── src/lib.rs                 # DB lifecycle harness + fixture helpers
└── test-contract/                 # test-support library (library-only)
    ├── Cargo.toml                 # depends on domain crates + test-db
    └── src/lib.rs                 # shared port-contract assertion functions
tests/                             # test-runner crates (binary tests)
├── integration/                   # HTTP-level integration / E2E tests (cross-crate wiring)
│   ├── Cargo.toml                 # depends on every domain crate + infrastructure + app + test-db
│   ├── src/lib.rs                 # shared test helpers (TestAppBuilder, fixtures)
│   └── tests/                     # test bodies (see "Test Layout" below)
├── usecase/                       # use-case branch coverage against a real database
└── infrastructure/                # infrastructure-adapter branch coverage against a real database
```

The three runners above are the **standard runner set** (see `~/.claude/rules/testing.md` "Layered Test Strategy" for which tests belong to which runner). A project starts with `tests/integration/` and creates `tests/usecase/` / `tests/infrastructure/` when their test tier first gets tests — do not scaffold empty runners upfront.

### Per-crate rules

- **Library by default**: every workspace crate exposes a `src/lib.rs`. Domain crates, `shared-kernel`, `infrastructure`, the test-support libraries under `crates/test-*/`, and the test-runner crates under `tests/<name>/` are library-only and have no `src/main.rs` or `src/bin/*.rs`.
- **Binaries live in `app` only**: only the `app` crate ships executables. Place each binary entry point under `app/src/bin/<name>.rs` and keep the file as a thin shim — parse arguments, build the composition root by calling into `app`'s library, translate errors to exit codes. No business logic.
  - Reason: integration tests are compiled as separate crates and can only import the library crates' public APIs. A bare `src/main.rs` binary has no library to import, so the test harness cannot exercise it. Splitting `app` into `app/src/lib.rs` + `app/src/bin/*.rs` makes the composition root reachable from both the binary and the test-runner crates under `tests/<name>/`.
- **Workspace-root `Cargo.toml`** is a virtual workspace: it declares `[workspace]` with the crate `members` list and shared `[workspace.dependencies]` / `[workspace.package]`, but no `[package]` of its own.

Violations of these rules are graded in the Severity Matrix at the bottom of this file.

### Dependency direction (workspace level)

The compiler enforces this graph through each crate's `Cargo.toml` `[dependencies]`. `code-reviewer` performs a second-stage review of the dependency declarations as a backstop.

- `shared-kernel` — depends on nothing.
- `<domain-*>` — depends only on `shared-kernel`. **Domain crates MUST NOT depend on each other.** Cross-domain orchestration goes through the central domain's use case calling other domains via injected ports (Gateway), never through a direct crate-to-crate dependency.
- `infrastructure` — depends on every domain crate and `shared-kernel`. It implements each domain's Repository / Gateway ports so all DB and external-IO concerns live here.
- `app` — depends on every crate. Wires the composition root, builds the Axum `Router`, owns binary entry points.
- `test-db` / `test-contract` (under `crates/`) — test-support libraries. `test-db` depends on `infrastructure` and the domain crates it seeds; `test-contract` depends on the domain crates whose port contracts it asserts plus `test-db`. Neither hosts test binaries.
- Test-runner crates under `tests/<name>/` — each depends on the domain crates it exercises, `infrastructure`, `app`, `test-db`, and (where contract tests are wired) `test-contract`. They exist only as test harnesses.

### Adapter placement

Adapters (HTTP controllers, request/response DTOs, presenters) live **inside each domain crate's `adapter/` module**, NOT in a separate workspace-level adapter crate. The `app` crate imports each domain's adapter module and composes the global router. This keeps domain cohesion high while still surfacing the routing graph from one place.

### Cross-domain use cases

A use case that touches multiple bounded contexts (e.g. "place order" reaching into inventory and payment) is implemented in the **most central domain's `usecase/` module**, with the other domains exposed as Gateway ports injected at composition. Do NOT introduce a workspace-level `application` crate for cross-domain orchestration — it usually signals the central domain has not been identified, or that domain boundaries themselves need revisiting (escalate to `architect`).

### Single-domain projects

If the project genuinely has one bounded context, the workspace structure still applies: one `<domain>` crate plus `shared-kernel`, `infrastructure`, `app` under `crates/`, and at minimum the `tests/integration/` test-runner crate under `tests/`. Resist collapsing into a single crate to save files — the dependency-direction protections only exist at the crate boundary, and adding a second domain later is much cheaper if the workspace is already in place.

### Structure review checklist

- [ ] The workspace splits crates **by bounded context**, not by Clean Architecture layer (no `entity` / `usecase` / `adapter` crates at workspace level).
- [ ] Each crate directory contains its own `Cargo.toml` declaring `[package]` and `[dependencies]`.
- [ ] Domain crate `Cargo.toml` files declare no dependency on other domain crates (verify in `[dependencies]`).
- [ ] `shared-kernel`'s `Cargo.toml` declares no dependency on any other workspace crate.
- [ ] Persistence and external-IO implementations live in the `infrastructure` crate; no domain crate contains DB pool / HTTP-client wiring.
- [ ] Each domain crate's source layout uses `entity/` / `usecase/` / `adapter/` modules; the inward-only direction is preserved within the crate via module visibility (`pub(crate)` and narrower).
- [ ] Cross-domain use cases live in the central domain's `usecase/` module and reach other domains only through Gateway ports.
- [ ] Integration / E2E tests live in a test-runner crate under `tests/<name>/` (standard runners: `tests/integration/`, `tests/usecase/`, `tests/infrastructure/`), not in any domain crate's `tests/` or in a `crates/test-*/tests/` directory (see "Test Layout").
- [ ] When the workspace has more than one test-support **library** crate under `crates/`, every such crate uses the `test-*` prefix. Test-runner crates under `tests/<name>/` are grouped by the `tests/` directory itself and do not require the prefix.

## Test Layout

This section refines the Testing rules from the global `CLAUDE.md` for Rust. BDD with the Detroit (classicist) school of TDD still applies — test real collaborators, mock only at architectural boundaries, verify state and output rather than interactions.

### Layout (workspace + test-runner crates under `tests/<name>/`)

- **Unit tests**: Co-located in the same file as the code under test, inside a `#[cfg(test)] mod tests { ... }` block. Scope is limited to the module's internals, including private items. Lives **inside the same crate** as the code under test (typically a domain crate, `shared-kernel`, or `infrastructure`).
- **Integration tests and E2E tests**: ALL integration and end-to-end tests live in test-runner crates under the workspace-root `tests/<name>/` directory (the standard runners are `tests/integration/` for HTTP-level wiring, `tests/usecase/` for use-case branch coverage against a real database, and `tests/infrastructure/` for infrastructure-adapter branch coverage against a real database — see "Directory and Crate Structure"). Each `.rs` file under `tests/<name>/tests/` is compiled as a separate test binary and may exercise the public APIs of the domain crates, the `infrastructure` crate, and the `app` crate via injected ports / composition.
  - The phrase "`tests/` directory" is ambiguous on its own — it refers to **two different things** in this rule: the workspace-root `tests/` directory (which IS the home for test-runner crates and is required) versus a `tests/` directory inside any individual crate (which is forbidden outside the test-runner crates' own `tests/<name>/tests/`).
  - Do NOT create a `tests/` directory inside any `crates/<production>/` crate (domain crates, `shared-kernel`, `infrastructure`, `app`) or inside any `crates/test-*/` test-support library. Those crates have unit tests only. The only allowed `tests/` directories are the test-runner crates' own `tests/<name>/tests/` (Cargo's per-crate integration-test directory inside the runner).
  - Do NOT place integration tests inside `src/` or inside `#[cfg(test)]` modules.
  - Do NOT test private items from integration tests — if coverage is missing, the API surface is wrong, not the test location.
  - Shared helpers (DB setup, fixtures, builders, test-only HTTP clients) live in `tests/<name>/src/lib.rs` (the runner crate's library entry). Each test file imports them with `use <runner_crate>::...;` (e.g. `use test_integration::...;` when the runner crate's `[package].name` is `"test-integration"`). The legacy `tests/common/mod.rs` pattern is not used here — the runner crate's own `lib.rs` already provides a stable home for helpers.
- **Test-support library naming**: Test-support **library** crates under `crates/` (e.g. a contract-test helper library or a shared DB-fixture library) MUST use the `test-*` prefix (`test-contract`, `test-db`, ...). The shared prefix keeps these libraries grouped together in alphabetical `crates/` listings and signals their non-production role at a glance. A single test-support library may use any name, but as soon as a second one is added the prefix becomes mandatory and existing crates MUST be renamed for consistency. Test-runner crates under `tests/<name>/` do NOT require the prefix — the `tests/` directory itself already groups them and signals their role; the runner crate's `[package].name` may follow either convention (e.g. `"test-integration"` is acceptable, so is `"tests-integration"` if a new runner is named afresh).
- **Doc tests**: Use for small, illustrative examples on public items. Do not rely on doc tests as the primary coverage mechanism.

### Why test-runner crates live under `tests/<name>/`

- **Physical grouping of test concerns**: each test-runner crate addresses a distinct test concern (HTTP-level integration in `tests/integration/`, use-case-level real-DB testing in `tests/usecase/`, infrastructure-adapter real-DB testing in `tests/infrastructure/`). Placing them under a shared `tests/` directory groups them at the directory level so a reader can scan `tests/<name>/` to enumerate all test-runner crates without reading `Cargo.toml`.
- **`crates/` stays focused on code**: production crates and test-support libraries live under `crates/`. Test-runner crates live under `tests/`. The split keeps `crates/` listings free of test-runner noise and makes the "production vs. test-execution" boundary visible in the directory tree.
- **Cross-domain scenarios** have a natural home in `tests/integration/`: the runner crate is the only place that depends on multiple domain crates plus `infrastructure` and `app`, so end-to-end flows across bounded contexts can be exercised without violating the inter-domain "no direct dependency" rule at the production layer.
- **Real persistence / HTTP-client implementations** live in `infrastructure`. Concentrating tests that wire `infrastructure` against domain ports in the test-runner crates keeps DB setup / teardown, transaction management, and fixture loading in one place per runner.
- Cargo compiles every file under `tests/<name>/tests/` as a separate test binary, so test-binary parallelism is preserved while shared helpers stay in a single library per runner.

Misplaced tests are graded in the Severity Matrix at the bottom of this file.

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

## Time and Clock Injection

- Never call `std::time::SystemTime::now()`, `chrono::Utc::now()`, or `tokio::time::Instant::now()` directly from the entity or use case layer. Doing so makes the code non-deterministic and untestable.
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
- `pub` items carry English docstrings only when the code alone cannot convey the contract (necessity criteria in `~/.claude/rules/docstrings.md`) — see "Docstrings (Rust overlay)" below for the Rust section layout. `# Errors` / `# Panics` / `# Safety` remain mandatory where applicable.
- Avoid re-exporting third-party types through your public API unless the dependency is intentionally part of your contract.

## Docstrings (Rust overlay)

This section maps the general rules in `~/.claude/rules/docstrings.md` onto Rust's idiomatic doc-comment conventions. On conflict with `docstrings.md`, this section wins for `.rs` files. Whether an item gets a docstring at all follows the necessity criteria in `docstrings.md` ("Document Only What the Code Cannot Say") — with one Rust-specific exception: `# Errors`, `# Panics`, and `# Safety` are **always required** where applicable, even on an item that would otherwise be self-evident, because those conditions are never recoverable from the signature.

### Comment style

- `///` documents the item that follows. Use it for `pub` functions, methods, structs, enums, unions, traits, type aliases, and constants.
- `//!` is an inner doc comment. Use it for module-level docs (top of `mod.rs` / `<module>.rs`) and crate-level docs (top of `src/lib.rs`).
- The `//!` overview is required only when multiple public items interact and the module only makes sense as a whole (see `docstrings.md` "Module-Level Overviews") — then write it like a Rust std library module page and keep each item's `///` short.
- Place doc comments directly above the item — no blank line between the comment and the item.
- Implementation-mechanic rationale (why a derive, why zero-sized, why error detail is dropped at a boundary) goes in ordinary `//` body comments next to the code — plain why-comments, no `// Why:` label — not in the `///` doc comment, which states the caller-facing information.

### Section heading layout

Rustdoc uses standard `#`-headed sections. When a docstring is warranted (per the necessity criteria), lay it out as follows. Headings inside a doc comment use a single `#` at the line start (`# Examples`, `# Errors`, ...).

| Content | Rust placement |
|---|---|
| Summary (one line) | First line of the doc comment, terminated by a blank line. Reused as the search-result snippet — keep it concise. |
| Purpose (when not obvious) | One or two sentences after the summary, before any `#`-headed section. Rationale shared by several items goes in the module `//!`; implementation-mechanic rationale goes in `//` body comments. |
| Non-obvious parameters / return | Bulleted list when 2+ need explanation; a single sentence otherwise. Add `# Arguments` / `# Returns` headings only when non-trivial. Self-describing parameters are not enumerated. |
| Error conditions | `# Errors` section. **Always required** when the function returns `Result` — even on an otherwise self-evident item. List the domain error variants and the conditions that trigger each. |
| Panic conditions | `# Panics` section. **Always required** whenever the function may panic, including a non-trivial `.expect("...")` and panics from a violated precondition. |
| Side effects | State them **when present** and not advertised by the name (I/O, state mutation, external call, blocking, async cancellation behavior). Purity is the default assumption — add "Pure" only when it aids the reader, never as a blanket marker. |
| Example | `# Examples` section with a runnable doc test in a ` ```rust ` fenced block. **Required** on traits and on `pub` functions whose intended usage is non-obvious. |
| Unsafe contract | `# Safety` section. **Always required** for every `unsafe fn` and `unsafe trait`, listing the invariants the caller must uphold. |

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

- Do NOT enable `#![warn(missing_docs)]` — docstring presence follows the necessity criteria in `docstrings.md`, not blanket coverage; the lint would force noise docstrings onto self-evident items. Prefer `clippy::missing_errors_doc` / `clippy::missing_panics_doc` / `clippy::missing_safety_doc` to enforce the always-required `# Errors` / `# Panics` / `# Safety` sections mechanically.
- Docstring-structure violations specific to Rust are graded in the Severity Matrix at the bottom of this file, in addition to the matrix in `docstrings.md`.

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
- **Layer discipline**: entity and use case layers MUST NOT emit log records. They return `Result<T, DomainError>`; the adapter / infrastructure layer decides how to log failures and successes. This keeps inner layers deterministic and framework-free.
- Use `#[tracing::instrument(...)]` on adapter / infra entry points to get automatic span coverage. Skip large or sensitive fields with `skip` / `skip_all`.
- Choose levels deliberately: `error` for failed operations a human must investigate, `warn` for recoverable anomalies, `info` for state transitions, `debug` for development detail, `trace` for hot-path diagnostics. Default production filter is `info`.
- Never log secrets, credentials, full PII, or raw request bodies. Redact at the adapter boundary.

## Dependency Hygiene

- Any new crate added to `Cargo.toml` requires the Dependency Approval Process from the global CLAUDE.md. No silent additions.
- Prefer the standard library and existing dependencies over pulling in new ones.
- **Always use the latest released version.** Before adding a dependency, check the current version on crates.io (`cargo search <name>` or `cargo add <name>` which resolves to latest) — do NOT copy an older version from memory or another project.
- **Version specifier format: `"xx.yy"` (major.minor only).** Example: `serde = "1.0"`, `tokio = "1.38"`. Do NOT write exact patches (`"1.38.0"`), caret prefixes (`"^1.38"`), tildes (`"~1.38"`), wildcards (`"*"`), or git dependencies. Cargo's default semver behavior on `"xx.yy"` already allows compatible patch and minor updates.
- When bumping a dependency, update to the latest major.minor and record the reason in the PR description if the bump crosses a major version.

## Dependency Injection Patterns

Both are acceptable; consistency within a project matters more than the choice.

- **Static dispatch** — generic parameters with trait bounds: `CreateUser<R: UserRepository, G: MailGateway>`. Zero runtime overhead, more verbose at the definition site.
- **Dynamic dispatch** — trait objects: `Arc<dyn UserRepository + Send + Sync>`. Simpler types, ergonomic with Axum `State`. Negligible vtable overhead. **Generally preferred for Web APIs.**

Checks:

- [ ] The DI style is consistent within the project.
- [ ] Type parameters have not exploded into unreadable generics.
- [ ] `Arc<dyn Trait>` usage declares `Send + Sync` appropriately.

## Ownership and Lifetimes at Layer Boundaries

- [ ] Methods returning Entities do not clone defensively; ownership transfer is deliberate.
- [ ] Repository parameter kind (`&T` vs. `T`) reflects intent — borrow for read, own for transfer / store.
- [ ] Lifetime annotations do not leak across layer boundaries and do not complicate inner-layer signatures.

## Axum Boundary Rules

### Extractors stay in Controllers

Extractors (`Json<T>`, `Path<T>`, `State<T>`) must appear only in Controller signatures. A Use Case method that accepts `Json<T>` is a framework leak (graded in the Severity Matrix below).

### Request / Response types belong in the Adapter layer

- [ ] Types carrying `#[derive(Serialize, Deserialize)]` live in the Adapter layer.
- [ ] Use Case Input / Output DTOs have no serde annotations.
- [ ] Request → Input DTO and Output DTO → Response conversions are performed inside the Controller.

### State and DI

- [ ] `State<T>` carries an `AppState` that holds all Use Cases / Gateways.
- [ ] `AppState` construction (the DI root) lives in `main.rs` or a dedicated composition module.

### Middleware

- [ ] Auth, logging, and similar middleware belong to the Adapter / Infrastructure layer.
- [ ] Middleware-produced values (e.g. authenticated user identity) are converted to Use Case-layer types before crossing into Use Cases — never Axum types.

## Severity Matrix

`code-reviewer` applies these severities verbatim, in addition to the matrices in `testing.md` / `docstrings.md` / `architecture.md`. On overlap, this file wins for Rust-specific observations (per `~/.claude/CLAUDE.md` Rules Directory Governance §4).

| Observation | Severity |
|---|---|
| Business logic in `app/src/main.rs` / `app/src/bin/*.rs` beyond the thin-shim responsibilities | 🔴 |
| Binary entry point (`main.rs` / `bin/*.rs`) in any crate other than `app` | 🔴 |
| Workspace-root `Cargo.toml` carrying a `[package]` section (must remain a virtual workspace) | 🔴 |
| Domain crate declaring a `Cargo.toml` dependency on another domain crate | 🔴 |
| `shared-kernel` declaring a dependency on any other workspace crate | 🔴 |
| Persistence / HTTP-client wiring (`sqlx`, `reqwest`, etc.) pulled into a domain crate instead of `infrastructure` | 🔴 |
| Integration / E2E test placed anywhere outside the test-runner crates under `tests/<name>/` | 🔴 |
| A `tests/` directory created inside a `crates/<production>/` crate or a `crates/test-*/` test-support library | 🔴 |
| Serde / framework derive on a domain entity, value object, or use case DTO | 🔴 |
| Use Case method accepting an Axum extractor (`Json<T>` / `Path<T>` / `State<T>`) | 🔴 |
| `pub` function returning `Result` without an `# Errors` section | 🔴 |
| Function that may panic (including a non-trivial `.expect("...")`) without a `# Panics` section | 🔴 |
| `unsafe fn` / `unsafe trait` without a `# Safety` section | 🔴 |
| Port-trait `# Errors` section naming infrastructure error types instead of domain variants (infrastructure leakage into the inner layer) | 🔴 |
| Hand-constructed URLs to other items instead of intra-doc links | 🟡 |
| Doc test marked `ignore` without an inline reason | 🟡 |
| `# Examples` block on a port trait that wires real infrastructure rather than a fake | 🟡 |
| Dependency version specifier with a patch number, caret / tilde / wildcard, or git ref — or a known-outdated minor (a newer minor exists on crates.io) | 🟡 |
