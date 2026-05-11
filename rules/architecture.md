---
paths:
  - "**/*.{rs,py,ts,tsx,js,jsx,mjs,cjs,go,java,kt,rb,cs,cpp,c,h,hpp,scala}"
  - "docs/design/**"
  - "docs/pr/**"
  - "docs/adr/**"
---

# Clean Architecture Review Guidelines

Authoritative rules for applying Clean Architecture to Rust Web API projects. Auto-load when Claude touches source files or design / PR / ADR docs matching the `paths:` above, and also loaded by `architect`, `developer`, and `code-reviewer` on demand via `Read`.

When this document and `~/.claude/rules/rust.md` overlap:

- **Rust-specific implementation detail** (Newtype mechanics, panic policy, serde rules, error-type crates, async runtime) → `rust.md` wins.
- **Layer responsibility, port placement, layer-boundary review observations** → this document wins.

---

## Core Principles

Dependencies point inward only. Outer layers know about inner layers; inner layers know nothing of outer.

```txt
Framework → Adapter → UseCase → Entity
(outer)                              (inner)
```

### Entity layer

> **Business rules live in Entities.**

- Business rules are implemented as Entity methods.
- Invariants are enforced in constructors / factory methods.
- Fields are private by default; invalid states are unrepresentable.
- **Repository interfaces are placed in the Entity layer** — persistence contracts for self-domain aggregates belong to the domain.

### Use Case layer

> **Use Cases do not execute business logic. They orchestrate.**

A Use Case is the conductor; Entities are the musicians. The Use Case decides *who plays when*, never *what note*. A healthy Use Case is thin.

- Use Cases coordinate Entities with Repositories / Gateways.
- Input / Output DTOs are defined in the Use Case layer. Entities never leak outward as part of a Use Case contract.
- **External Gateway interfaces are placed in the Use Case layer** — external-system communication is an application concern, not a domain one.
- Use-case-specific queries and aggregations belong to a `QueryService` in this layer.

### Adapter layer

> **Adapters translate. They never judge.**

Adapters bridge inner contracts and outer technology (HTTP, DB, external services). Business judgement stays inside; Adapters handle format conversion, protocol adaptation, and technical implementation. Any `if` in an Adapter should be a *technical* branch, never a *business* branch.

- Controllers handle input translation (Request → Input DTO) and Use Case invocation.
- Presenters handle output translation (Output DTO → Response).
- Repository implementations fulfil Entity-layer interfaces using DB / ORM.
- Gateway implementations fulfil Use Case-layer interfaces using HTTP clients etc.
- Technical detail (SQL queries, JSON conversion, retry logic) lives here.

### Framework & Drivers layer

> **Framework layer wires and starts. No business logic.**

The outermost layer owns the technology itself (web framework, DI wiring, DB connection, runtime). Replacing it must not affect inner business logic.

- `main.rs` handles DI wiring and server startup.
- Routing, middleware, DB pool initialization live here.
- Env vars and config file loading are a Framework concern.

---

## Interface Placement Rule (non-negotiable)

One axis of judgement: **is the target a self-domain concept, or an external system?**

- **Repositories always live in the Entity layer** — persistence contract for a self-domain aggregate.
- **Gateways always live in the Use Case layer** — communication contract with an external system.
- The same kind of interface must not be scattered across multiple layers.
- If an exception feels necessary, first check whether `QueryService` (in the Use Case layer) is the correct abstraction.

### Placement judgement table

| Subject | Examples | Placed in |
|---------|----------|-----------|
| Persistence of self-domain aggregates | `UserRepository`, `OrderRepository` | **Entity layer** |
| Communication with external systems | `PaymentGateway`, `AuthProvider` | **Use Case layer** |
| Use-case-specific search / aggregation | `OrderSummaryQuery`, `DashboardReadModel` | **Use Case layer** |
| Secondary external integrations | `MailNotifier`, `EventPublisher` | **Use Case layer** |

---

## What Belongs in Each Layer

### Entity layer (Domain)

- Entities / aggregates (the logic that enforces invariants)
- Value objects
- Domain services (logic that does not fit in a single Entity)
- **Repository interfaces** (self-domain aggregate persistence contracts)
- Domain events

### Use Case layer (Application)

- Use Cases (Interactors)
- Input DTOs / Output DTOs
- **External Gateway interfaces** (external APIs, auth, notification, etc.)
- QueryService / ReadModel interfaces (use-case-specific search / aggregation)
- Notifier / Mailer ports

### Adapter layer (Interface Adapters)

**Driving adapters (inbound):**

- Controllers (HTTP input)
- Event handlers (message queue, webhook)
- Scheduler / batch job runners
- CLI adapters

**Driven adapters (outbound):**

- Repository implementations
- Gateway implementations (HTTP client, payment, notification)
- Presenters / serializers (output translation)
- Mappers / translators (DB record ↔ Entity conversion)
- Cache / storage implementations

### Framework & Drivers layer (Infrastructure)

- Web framework (Axum, Actix-web, etc.)
- DI container / wiring
- DB / ORM / migrations
- HTTP clients, SDKs
- Tokio runtime, middleware

---

## Directory and Crate Structure

Rust projects MUST use a Cargo workspace, split **by bounded context (domain)** rather than by Clean Architecture layer. Splitting by domain keeps related business rules cohesive within one crate so a reader can follow a domain end-to-end without crate hopping; technical concerns (DB, external IO) are concentrated in a separate `infrastructure` crate. Layered splits at workspace level (`domain` / `usecase` / `adapter` crates) are NOT used in this project.

### Workspace layout (project default)

```text
Cargo.toml                         # workspace root: declares [workspace] members (no [package])
crates/
├── shared-kernel/
│   ├── Cargo.toml                 # [package] no workspace dependencies
│   └── src/lib.rs                 # cross-cutting value objects and ports (Clock, Money, Email, etc.)
├── <domain-a>/                    # bounded context A (e.g. user, order, payment)
│   ├── Cargo.toml                 # [package] dependencies = shared-kernel only
│   └── src/
│       ├── lib.rs
│       ├── domain/                # entities, value objects, repository ports, domain errors
│       ├── usecase/               # use cases, input/output DTOs, gateway / query-service ports
│       └── adapter/               # controllers, presenters, request/response DTOs
├── <domain-b>/
│   ├── Cargo.toml
│   └── src/{lib.rs, domain/, usecase/, adapter/}
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
└── test-integration/              # cross-crate integration / E2E tests
    ├── Cargo.toml                 # depends on every domain crate + infrastructure + app
    ├── src/lib.rs                 # shared test helpers (DB setup, fixtures)
    └── tests/                     # integration / E2E test bodies (see rust.md "Test Layout")
```

**Test-support crate naming**: When a workspace contains more than one test-support crate (e.g. an integration-test harness alongside a contract-test harness or a shared DB-fixture crate), use the **`test-*` prefix** consistently — `test-integration`, `test-contract`, `test-db`, etc. The shared prefix groups them together in alphabetical workspace listings and signals their non-production role at a glance. A single test-support crate may use any name, but as soon as a second one is added the prefix becomes mandatory and existing crates MUST be renamed for consistency.

### Dependency direction (workspace level)

The compiler enforces this graph through each crate's `Cargo.toml` `[dependencies]`. `code-reviewer` performs a second-stage review of the dependency declarations as a backstop.

- `shared-kernel` — depends on nothing.
- `<domain-*>` — depends only on `shared-kernel`. **Domain crates MUST NOT depend on each other.** Cross-domain orchestration goes through the central domain's use case calling other domains via injected ports (Gateway), never through a direct crate-to-crate dependency.
- `infrastructure` — depends on every domain crate and `shared-kernel`. It implements each domain's Repository / Gateway ports so all DB and external-IO concerns live here.
- `app` — depends on every crate. Wires the composition root, builds the Axum `Router`, owns binary entry points.
- `test-integration` — depends on every domain crate, `infrastructure`, and `app`. It exists only as a test harness.

### Adapter placement

Adapters (HTTP controllers, request/response DTOs, presenters) live **inside each domain crate's `adapter/` module**, NOT in a separate workspace-level adapter crate. The `app` crate imports each domain's adapter module and composes the global router. This keeps domain cohesion high while still surfacing the routing graph from one place.

### Cross-domain use cases

A use case that touches multiple bounded contexts (e.g. "place order" reaching into inventory and payment) is implemented in the **most central domain's `usecase/` module**, with the other domains exposed as Gateway ports injected at composition. Do NOT introduce a workspace-level `application` crate for cross-domain orchestration — it usually signals the central domain has not been identified, or that domain boundaries themselves need revisiting (escalate to `architect`).

### Single-domain projects

If the project genuinely has one bounded context, the workspace structure still applies: one `<domain>` crate plus `shared-kernel`, `infrastructure`, `app`, and `test-integration`. Resist collapsing into a single crate to save files — the dependency-direction protections only exist at the crate boundary, and adding a second domain later is much cheaper if the workspace is already in place.

### Structure review checklist

- [ ] The workspace splits crates **by bounded context**, not by Clean Architecture layer (no `domain` / `usecase` / `adapter` crates at workspace level).
- [ ] Each crate directory contains its own `Cargo.toml` declaring `[package]` and `[dependencies]`.
- [ ] Domain crate `Cargo.toml` files declare no dependency on other domain crates (verify in `[dependencies]`).
- [ ] `shared-kernel`'s `Cargo.toml` declares no dependency on any other workspace crate.
- [ ] Persistence and external-IO implementations live in the `infrastructure` crate; no domain crate contains DB pool / HTTP-client wiring.
- [ ] Each domain crate's source layout uses `domain/` / `usecase/` / `adapter/` modules; the inward-only direction is preserved within the crate via module visibility (`pub(crate)` and narrower).
- [ ] Cross-domain use cases live in the central domain's `usecase/` module and reach other domains only through Gateway ports.
- [ ] Integration / E2E tests live in the `test-integration` crate (see `rust.md` "Test Layout"), not in any domain crate's `tests/`.
- [ ] When the workspace has more than one test-support crate, every such crate uses the `test-*` prefix.

---

## Per-Layer Review Observations

### Entity layer

**Responsibility:**

- [ ] No inward import from outer layers. Scan `use` statements — no `axum`, `sqlx`, `reqwest`, etc.
- [ ] Business rules live in the Entity (not an anemic struct with logic pushed to Use Cases).
- [ ] Repository interfaces do not expose DB-specific method names.
- [ ] Repositories return Entities, not DB row structs or DTOs.

**Type design:**

- [ ] Domain concepts wrapped in Newtypes, not raw `String` / `i64` / `Uuid` (see `rust.md` "Domain Modeling — Newtype Pattern").
- [ ] Entity fields default to private; `pub` is justified per field.
- [ ] Invariants enforced in constructors or factory methods.
- [ ] No serde / framework derives on Entities (see `rust.md` "Serde and Framework Boundaries").

### Use Case layer

**Responsibility:**

- [ ] The Use Case is thin — orchestration only. No business branching or calculation.
- [ ] If a business condition is expressed as an `if` in a Use Case, consider moving it to an Entity.
- [ ] Input / Output DTOs carry no external-protocol concerns (no serde, no HTTP types).
- [ ] Gateway interfaces are protocol-agnostic (not tied to HTTP / gRPC in their signatures).
- [ ] Use Cases do not call other Use Cases. Repeated chains signal a missing domain service.

**Trait design:**

- [ ] Repository / Gateway traits carry appropriate `Send + Sync` bounds for async execution.
- [ ] `async_trait` vs. native async fn in trait usage is consistent project-wide.
- [ ] Gateways do not mix persistence responsibilities.

### Adapter layer

**Controller / event handler:**

- [ ] Controllers only translate input and invoke a Use Case. No business logic.
- [ ] Axum extractors (`Json<T>`, `Path<T>`, ...) stop at the Controller signature.
- [ ] Event handlers consider idempotency.

**Presenter / serializer:**

- [ ] Output translation only. No additional Use Case calls here (N+1 source).
- [ ] Response types carry `#[derive(Serialize)]` and stay in the Adapter layer.

**Repository / Gateway implementations:**

- [ ] Implement the inner-layer interface faithfully.
- [ ] No business logic smuggled in — a business `if` in an implementation is a responsibility leak.
- [ ] Repository implementations do not call external APIs; Gateway implementations do not persist data.
- [ ] Gateway implementations apply resilience patterns (retry, timeout, circuit breaker) where appropriate.

**Mappers:**

- [ ] DB record ↔ Entity conversion is bidirectionally consistent.
- [ ] No edge-case business logic hidden in a Mapper.

### Framework & Drivers layer

- [ ] DI wiring preserves the inward-only direction.
- [ ] Routing and configuration follow the project's standard pattern.
- [ ] Framework-specific types do not leak into inner layers.
- [ ] `main.rs` is wiring only — no business logic (enforced as 🔴 by `rust.md`).

---

## Dependency Injection Patterns (Rust)

Both are acceptable; consistency within a project matters more than the choice.

- **Static dispatch** — generic parameters with trait bounds: `CreateUser<R: UserRepository, G: MailGateway>`. Zero runtime overhead, more verbose at the definition site.
- **Dynamic dispatch** — trait objects: `Arc<dyn UserRepository + Send + Sync>`. Simpler types, ergonomic with Axum `State`. Negligible vtable overhead. **Generally preferred for Web APIs.**

Checks:

- [ ] The DI style is consistent within the project.
- [ ] Type parameters have not exploded into unreadable generics.
- [ ] `Arc<dyn Trait>` usage declares `Send + Sync` appropriately.

---

## Ownership and Lifetimes at Layer Boundaries

- [ ] Methods returning Entities do not clone defensively; ownership transfer is deliberate.
- [ ] Repository parameter kind (`&T` vs. `T`) reflects intent — borrow for read, own for transfer / store.
- [ ] Lifetime annotations do not leak across layer boundaries and do not complicate inner-layer signatures.

---

## Layered Error Types

Boundary conversion and crate selection (`thiserror` / `anyhow`) live in `rust.md`. This document specifies the *layering*:

- `DomainError` — defined in the Entity layer.
- `UseCaseError` — defined in the Use Case layer, wraps `DomainError` and any repository / gateway error.
- Response conversion (e.g. `impl IntoResponse for UseCaseError`) — defined in the Adapter layer.

Checks:

- [ ] Each layer owns its own error type; there is no single project-wide error enum spanning layers.
- [ ] Adapter-layer response conversion exists wherever the project exposes a protocol.

---

## Axum Boundary Rules

### Extractors stay in Controllers

Extractors (`Json<T>`, `Path<T>`, `State<T>`) must appear only in Controller signatures. A Use Case method that accepts `Json<T>` is a framework leak and is 🔴.

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

---

## Reading Order During Review

When the change touches multiple layers, read the diff in the order where intent is clearest first:

```text
Use Case → Entity → Adapter → Framework
```

1. **Use Case** — what the PR is trying to do.
2. **Entity** — whether the domain rules the Use Case relies on are sound.
3. **Adapter** — whether the inner contract is implemented faithfully.
4. **Framework** — whether wiring is correct.

Health indicators:

- A **thin** Use Case layer is healthy.
- A **rich** Entity layer is healthy (meaning density, not line count).
- **Bulk in the Adapter layer is natural** — translation code dominates.
- Focus attention on code that departs from these patterns.

PR scope:

- [ ] The PR is not sprawling across too many layers at once.
- [ ] Because layers are naturally separable, a large PR should be splittable.
- [ ] If the reviewer cannot complete the review, propose splitting.

---

## Severity Mapping (for `code-reviewer`)

Architecture-level findings map to 🔴 / 🟡 / 💭 as follows. `code-reviewer` uses this table directly and does not re-derive severity.

| Tier | Severity | Examples |
|------|----------|----------|
| **Critical** — must fix | 🔴 blocker | Dependency direction violation (inner importing outer); framework / ORM leakage into an Entity; Repository returning DB row type; Use Case accepting an Axum extractor; Repository interface placed outside the Entity layer; Gateway interface placed outside the Use Case layer. |
| **Major** — normally fix | 🔴 or 🟡 (see below) | Business logic in a Use Case `if`; domain concept carried as raw `String` / `i64`; serde annotation on an Input / Output DTO; missing layered error types; `pub` Entity fields without justification. |
| **Minor** — improvement recommended | 💭 or 🟡 | Weak Newtype validation; inconsistent `async_trait` vs. native async fn; `unwrap()` / `expect()` in inner layers; oversized conversion code in a Repository impl that should be a Mapper; missing resilience patterns (retry, timeout, circuit breaker) in a Gateway impl. |

**Major → 🔴 vs. 🟡:**

- Directly affects security / data integrity / API contract (e.g. an authorization check placed outside the Use Case, serde on a DTO causing an external schema diff) → 🔴.
- Refactorable without externally visible change (e.g. narrowing a `pub` field to `pub(crate)`) → 🟡.

**Severity precedence when other guideline files apply:**

- Test observations — `~/.claude/rules/testing.md` wins.
- Docstring observations — `~/.claude/rules/docstrings.md` wins.
- Rust-specific observations with an explicit severity in `rust.md` — `rust.md` wins.
- This document's severity applies only to layer-responsibility / dependency-direction / port-placement observations not covered above.

---

## Agent Usage

### architect

- Authoritative reference for deciding the layer of Use Cases, ports, and error types.
- "Interface Placement Rule" and "What Belongs in Each Layer" drive design decisions.
- When a `docs/design/<bounded-context>/` directory explains layer structure or port placement, cite the relevant sections of this document.

### developer

- Consult before writing code that crosses a layer boundary (DTOs, Entities, ports).
- If implementation appears to require breaking a rule in this document, STOP and escalate to `architect`. Do not soften the rule unilaterally.

### code-reviewer

- "Per-Layer Review Observations" is a mandatory checklist for every review.
- Assign severity per the "Severity Mapping" table.
- On conflict with `testing.md` / `docstrings.md` / `rust.md`, the more specific document wins.

### pr-writer

- Not a primary reader of this document.
- When a design document cites a section here, preserve the citation in the PR document as-is.

---

## Glossary

| Term | Definition | Layer |
|------|------------|-------|
| Entity | Domain object carrying business rules | Entity |
| Value object | Small domain concept with value equality and immutability | Entity |
| Repository | Contract to persist / retrieve a **self-domain aggregate** | Interface in Entity; impl in Adapter |
| Use Case (Interactor) | Application-specific orchestration of domain logic | Use Case |
| Gateway | Abstraction over communication with an **external system** | Interface in Use Case; impl in Adapter |
| QueryService / ReadModel | Contract for use-case-specific search / aggregation | Interface in Use Case; impl in Adapter |
| Controller | Translates input (HTTP, etc.) into an Input DTO and invokes a Use Case | Adapter |
| Presenter | Translates an Output DTO into an external-facing response | Adapter |
| Mapper | Converts between DB records and Entities | Adapter |
| DTO | Inter-layer data carrier | Layer of definition |

---

## Note: When Sources Disagree

Clean Architecture has many interpretations. Sources differ on:

- Where the Repository interface lives (Entity layer vs. Use Case layer).
- Whether "Gateway" covers all Repositories or only external-system communication.
- Whether a Presenter handles both directions or only output.
- Directory naming (`domain` vs. `entity`, `application` vs. `usecase`).

**This project adopts the interpretation codified in this document.** When in doubt, return to this guide.

*The guide is written with Rust × Axum in mind, but the principles apply to Actix-web, Rocket, and other Rust web frameworks.*
