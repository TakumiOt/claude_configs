# Testing Guidelines

These rules apply to all projects regardless of language. They are loaded on demand by the `architect`, `developer`, and `code-reviewer` agents (via `Read`) rather than being inlined into the global `CLAUDE.md`, so they stay authoritative without bloating every conversation.

Follow **BDD (Behavior-Driven Development)** with the **Detroit school (classicist)** approach. The core rule of Detroit school is: **use real objects for any module you own, and reserve mocks for collaborators that lie outside your control**. Apply this rule consistently across every test layer.

## Core Principles

- Describe behavior in terms of what the system does, not how it does it.
- Test names express business requirements (e.g. `rejects_expired_tokens`), not method names.
- Structure tests with Arrange-Act-Assert / Given-When-Then.
- Verify state and output, not internal method calls or interaction details.
- If a test is hard to write without mocks, it signals a design problem — fix the design, not the test.

## Test Double Taxonomy (distinguish rigorously)

Test doubles MUST be classified into one of the three categories below. Do **not** conflate them under the umbrella term "mock".

- **Fake** — A lightweight alternative implementation that honors the same contract as the production type (e.g. a `Vec` / `HashMap`-backed in-memory repository). Holds state, behaves similarly to the real thing. **Fakes are allowed for self-managed modules** and are the preferred double under Detroit school.
- **Stub** — A passive double that returns hard-coded values to drive a particular branch. Characteristic of the London (mockist) school. **Stubs are disallowed by default.** A test that can only be written with a stub is a signal to fix the design, not to add the stub.
- **Boundary Mock** — A double used to replace an external I/O boundary (external HTTP service, a separate process, the filesystem, etc.). **Mocks are reserved for collaborators outside our control.**

## Layered Test Strategy

Self-managed modules (domain / use case / middleware / infrastructure we own) MUST be exercised with real implementations by default. When a double is unavoidable, prefer `Fake` over `Mock` and never use `Stub`.

| Layer | Style | Allowed doubles |
|---|---|---|
| Entity / Domain (pure value objects) | Detroit | None — use the real type |
| Use Case | Detroit | **Fake** (in-memory) for repositories; **Boundary Mock** for external I/O ports; real instances for everything else we own (signers, verifiers, crypto) |
| Middleware | Detroit | Same as use case |
| Infrastructure — pure logic (crypto, hashing, HMAC, JWT, etc.) | Detroit | None — use the real implementation |
| Infrastructure — DB / external API bindings | Covered by integration tests | Do not write unit tests at this layer |
| Adapter / Handler | Covered by integration tests | — |
| Integration tests | Detroit | Only **Boundary Mocks** for external I/O |

## Unit Tests vs. Integration Tests

**Overlap is a deliberate division of labor, not waste.** Verifying the same business rule at different levels of abstraction is legitimate.

- **Unit tests** — Fast and exhaustive. Responsible for **branch coverage, boundary conditions, and error paths**. Verify the internal behavior of a self-managed module.
- **Integration tests** — Slower, happy-path oriented. Responsible for **cross-layer wiring**: real SQL execution, middleware traversal, crypto wiring, HTTP response mapping.

### Where Does an Observation Belong?

- **Belongs in unit tests**: branch coverage, boundary values, error-message wording, pure logic, implementation-specific edge cases.
- **Belongs in integration tests**: representative happy paths, cross-layer wiring, end-to-end auth/authz flows, real SQL execution.
- **Belongs in both (intentionally)**: critical business rules and auth boundaries — branch coverage in unit tests, end-to-end happy-path coverage in integration tests.
- **Must be deleted**: structure-mirroring tests of the shape "if the port returns X, the use case does Y", **when the integration test already covers the same observable outcome**. They are redundant and bind tests to implementation details.

## Performance vs. Principle

Using the real implementation is the default, even for self-managed modules. When a real implementation is noticeably expensive (e.g. Argon2's deliberate work factor), **suspect the production design first**. A slow test is often a symptom of a scalability problem in production, not a reason to loosen the test.

- **Principle**: Do **not** weaken production crypto parameters, add test-only bypasses, or replace a self-managed collaborator with a stub in order to make tests fast.
- **Slow tests as a diagnostic signal**: Treat slow tests on real self-managed modules as visible evidence of a production design issue, and address them through production improvements in a follow-up task.
- **Ordering of compromises**: "tolerate slow unit tests that run against the real thing" > "introduce a test-only hook into production code" > "fake it with a stub or mock".

## TDD Workflow

1. Write a failing test that describes the expected behavior (Red).
2. Write the minimum code to make it pass (Green).
3. Refactor while keeping tests green.

When adding a new test, consciously decide **which layer the test belongs to** and **which collaborators (if any) need to be replaced with a double**, based on the table above. Do not mechanically copy an existing test pattern.

## Review Severity (for `code-reviewer`)

- Heavy internal mocking of self-managed modules → 🟡 (design smell). If it replaces a collaborator we own with a `Stub`, → 🔴.
- Test name that reproduces the method name instead of the behavior → 🟡.
- Structure-mirroring test duplicated by an integration test covering the same outcome → 🟡 (delete the unit test).
- Test-only bypass or weakened parameter in production code introduced "to make tests fast" → 🔴.
- Integration-only `Boundary Mock` used in place of a real self-managed collaborator → 🔴.
