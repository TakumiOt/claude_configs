# Global Preferences

## Development Workflow (MANDATORY)

IMPORTANT: All development work MUST be delegated to the specialized agents in `~/.claude/agents/`. Do not implement features, write tests, or review code directly in the main conversation.

Agents and their responsibilities:

1. **architect** — Design phase. Produces use cases, port interfaces, domain error types, ADRs, and trade-off analyses. Does NOT write implementation code.
2. **developer** — Implementation phase. Writes tests and code across all Clean Architecture layers using BDD + Detroit-school TDD (Red → Green → Refactor).
3. **code-reviewer** — Review phase. Independently reviews changes for architecture compliance, dependency health, and business application concerns. Does NOT modify code.

Standard workflow for any non-trivial feature or change:

1. Invoke `architect` first to design the use case, ports, and error types.
2. Invoke `developer` with the architect's output to implement via TDD.
3. Invoke `code-reviewer` after implementation to get independent feedback.
4. If blockers/suggestions are raised, re-invoke `developer` with the findings.

### Orchestration Loop (MANDATORY)

For every non-trivial change, the main conversation MUST execute the following loop end-to-end **without pausing to ask the user between phases**. The point of delegating to agents is that the main thread orchestrates them; do not stop after architect or developer and wait for permission to proceed.

1. **architect** → produces design artifacts (use cases, ports, error types, ADRs as needed).
2. **developer** → implements via TDD using the architect's output, satisfies the Definition of Done, reports the full modified-file list.
3. **code-reviewer** → independently reviews the change and returns findings categorized as 🔴 blocker / 🟡 suggestion / 💭 nit.
4. **Fix loop**: If code-reviewer returns any 🔴 blocker, OR any 🟡 suggestion that the user has not explicitly deferred, re-invoke `developer` with the review findings as input. Then go back to step 3.
5. The loop exits only when code-reviewer returns **zero 🔴 blockers** and all non-deferred 🟡 items are addressed. Only then is the task considered ready for user review.

The user is consulted **only** at these points (never between phases of the loop itself):

- **Dependency approval** (per the Dependency Approval Process below).
- **Ambiguous requirements** that the architect cannot resolve from the available context.
- **Non-convergence escalation**: if the loop has executed step 3 → step 4 → step 3 three times without converging, stop and escalate to the user with a summary of what is blocking convergence.

**Git operations are entirely the user's responsibility.** No agent and no main-conversation flow may run `git commit` / `push` / `merge` / `rebase` / `reset` / `checkout -b` / branch deletion / tag operations — not even to ask for approval. Read-only commands (`git status` / `git diff` / `git log` / `git show`) remain available for investigation. Do not propose, suggest, or stage commits; the user handles all version control actions themselves.

When invoking the next agent in the loop, always pass the previous agent's output (design artifacts, modified file list, or review findings) as context — never ask the next agent to re-discover what the previous one already produced.

Exceptions (main conversation may handle directly):

- Trivial edits: typo fixes, comment updates, config value tweaks.
- Read-only investigation: answering questions, explaining code, `git status` / `git diff` / `git log`.
- Agent definition maintenance itself (editing files under `~/.claude/agents/`).

When in doubt, delegate. Prefer invoking an agent over implementing directly.

### Definition of Done (ALL items MUST be satisfied)

A development task is NOT complete until every item below is true. The `developer` agent MUST verify this list before declaring work finished. The `code-reviewer` agent MUST reject any hand-off that skips these items.

1. **Design artifacts exist**: `docs/design/<feature>.md` is written/updated and includes acceptance criteria (in Japanese). ADRs created when applicable.
2. **Failing test first**: Every new behavior was introduced via a failing test before production code.
3. **All tests pass**: Full test suite green. For Rust: run via `cargo make` (e.g. `cargo make test`). Do NOT use bare `cargo test` — project-standard task runner is `cargo make`.
4. **Linter / static analysis clean**: For Rust: `cargo make` task for lint/clippy passes with no warnings. For other languages: equivalent project-standard task runner must pass.
5. **Build succeeds**: `cargo make` build task passes (Rust) or language equivalent.
6. **Docstrings present**: All public API elements (functions, structs, traits, modules visible across module boundaries) have **English** docstrings. Port docstrings start from the draft in the design document and are refined against the implementation.
7. **Function size**: No function exceeds 50 lines.
8. **No commented-out code, no orphan TODO/FIXME**: TODO/FIXME only if linked to an issue/ticket.
9. **Modified file list reported**: The `developer` agent reports the full list of created/modified files at hand-off.
10. **Independent review passed**: `code-reviewer` has reviewed the change and all 🔴 blockers are resolved. 🟡 suggestions are either addressed or explicitly deferred with rationale.
11. **No Git operations performed**: No agent has executed (or proposed) any state-modifying git command. The user handles all commit/push/merge/rebase/branch operations themselves.

### Dependency Approval Process (MANDATORY)

Adding a new external library/crate/package requires explicit approval. No agent may add a dependency without going through this flow.

1. **Identification**: The `architect` agent surfaces dependency needs during the design phase. If implementation reveals an unforeseen need, the `developer` agent MUST stop and escalate — do NOT add it silently.
2. **Justification**: Propose the dependency to the user in Japanese with:
   - Purpose (what problem it solves)
   - Alternatives considered (including "write it ourselves")
   - Health check results: last release date, commit activity, GitHub stars, maintainer count, license, known CVEs
   - Impact on build time / binary size / transitive dependency count (if significant)
3. **User approval**: Wait for explicit user approval before modifying `Cargo.toml` / `package.json` / `pyproject.toml` / etc. Silent dependency additions are prohibited.
4. **Record**: Once approved, record the rationale in the relevant `docs/design/<feature>.md` or as a dedicated ADR if the choice is load-bearing.
5. **Review enforcement**: The `code-reviewer` agent MUST flag any dependency change not accompanied by an approval record as a 🔴 blocker.

## Language

- Always respond in Japanese
- Use English for code comments and variable names

## Coding

- No speculative features — only build what's needed now
- Replace, don't deprecate
- Functions must be under 50 lines
- Write self-explanatory code — inline comments should explain "why", not "what"
- Write docstrings in **English** for all public functions, classes, and modules
- Do not leave commented-out code — delete it (git history preserves it)
- Do not add TODO/FIXME without an associated issue or ticket
- When compacting, preserve the list of modified files

## Architecture

IMPORTANT: Follow Clean Architecture principles.

Layer structure (inner → outer):

1. Entities — Core business rules, no external dependencies
2. Use Cases — Application-specific logic, depends only on Entities
3. Adapters — Controllers, presenters, gateways (implements interfaces)
4. Infrastructure — Frameworks, DB, external APIs

Rules:

- Dependencies must always point inward — inner layers never import from outer layers
- Define interfaces (ports) in inner layers, implement them in outer layers
- Do not leak framework-specific types into use cases or entities
- When adding a new feature, start from the use case layer, not from the framework

## Error Handling

- Define domain-specific error types in the Entities/Use Cases layer
- Do not let infrastructure exceptions leak into inner layers — catch and convert at the boundary
- Use explicit error types (Result/Either) over throwing exceptions where the language supports it
- Fail fast on unrecoverable errors, handle gracefully on expected errors
- Log errors at the Infrastructure layer, not in domain logic

## Testing

IMPORTANT: Follow BDD (Behavior-Driven Development) with Detroit school (classicist) approach.

Principles:

- Describe behavior in terms of what the system does, not how it does it
- Test names should express business requirements (e.g., "it should reject expired tokens")
- Structure tests with Arrange-Act-Assert / Given-When-Then

Detroit school rules:

- Test real objects and their actual collaborators — avoid mocks unless crossing architectural boundaries
- Mock only external dependencies (DB, API, file system, etc.)
- Verify state and output, not internal method calls or interaction details
- If a test is hard to write without mocks, it signals a design problem — fix the design

Workflow:

1. Write a failing test that describes the expected behavior
2. Write the minimum code to make it pass
3. Refactor while keeping tests green

## Language-Specific Guidelines

Per-language conventions live under `~/.claude/guidelines/` and are imported below. They override general guidance on conflict. All agents (`architect`, `developer`, `code-reviewer`) MUST read the relevant file before starting work on a project in that language.

@~/.claude/guidelines/rust.md

## Git Operations

IMPORTANT: Git operations are owned entirely by the user. Do not execute or propose any state-modifying git command — not even to ask for approval.

- Never run: `commit`, `push`, `merge`, `rebase`, `reset`, `checkout -b`, branch/tag create/delete, `stash`, `cherry-pick`, etc.
- Never suggest "shall I commit this?" or stage changes in anticipation of a commit.
- Read-only commands are allowed freely: `git status`, `git diff`, `git log`, `git show`, `git blame`.
- When work is complete, just report what changed and stop. The user will commit themselves.
