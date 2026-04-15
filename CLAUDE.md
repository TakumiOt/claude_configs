# Global Preferences

## Development Workflow (MANDATORY)

IMPORTANT: All development work MUST be delegated to the specialized agents in `~/.claude/agents/`. Do not implement features, write tests, or review code directly in the main conversation.

Agents and their responsibilities:

1. **architect** — Design phase. Produces use cases, port interfaces, domain error types, ADRs, and trade-off analyses. Does NOT write implementation code.
2. **developer** — Implementation phase. Writes tests and code across all Clean Architecture layers using BDD + Detroit-school TDD (Red → Green → Refactor).
3. **code-reviewer** — Review phase. Independently reviews changes for architecture compliance, dependency health, and business application concerns. Does NOT modify code.

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

When invoking the next agent in the loop, always pass the previous agent's output (design artifacts, modified file list, or review findings) as context — never ask the next agent to re-discover what the previous one already produced.

Git operations are entirely the user's responsibility — see the `## Git Operations` section below. This applies inside the loop as well: no agent stages, commits, or proposes a commit.

Exceptions (main conversation may handle directly):

- Trivial edits: typo fixes, comment updates, config value tweaks.
- Read-only investigation: answering questions, explaining code, `git status` / `git diff` / `git log`.
- Agent definition maintenance itself (editing files under `~/.claude/agents/`).

When in doubt, delegate. Prefer invoking an agent over implementing directly.

### Definition of Done (ALL items MUST be satisfied)

A development task is NOT complete until every item below is true. The `developer` agent MUST verify this list before declaring work finished. The `code-reviewer` agent MUST reject any hand-off that skips these items.

1. **Design artifacts exist**: `docs/design/<feature>.md` written/updated with acceptance criteria in Japanese. ADRs created when applicable.
2. **Test-first**: Every new behavior was introduced via a failing test before production code (see `~/.claude/guidelines/testing.md`).
3. **Task runner green**: Full test + lint + build via the project's task runner (Rust: `cargo make test` / `cargo make lint` / `cargo make build` — never bare `cargo test`). Zero warnings.
4. **Docstrings present**: All public API elements have **English** docstrings. Port docstrings start from the draft in the design document and are refined against the implementation.
5. **Function size**: No function exceeds 50 lines.
6. **No commented-out code, no orphan TODO/FIXME**: TODO/FIXME only if linked to an issue/ticket.
7. **Modified file list reported**: `developer` reports the full list of created/modified files at hand-off.
8. **Independent review passed**: `code-reviewer` reviewed the change; all 🔴 blockers resolved; 🟡 suggestions addressed or explicitly deferred with rationale.

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

Size, docstrings, comments, and TODO rules are covered by the Definition of Done — they are not repeated here. Additional rules:

- No speculative features — only build what's needed now.
- Replace, don't deprecate — remove old code outright; git history preserves it.
- Inline comments explain *why*, never *what*.
- When compacting, preserve the list of modified files.

## Architecture & Error Handling

IMPORTANT: Follow Clean Architecture. Layers inward → outward: **Entities → Use Cases → Adapters → Infrastructure**. Dependencies point inward only. Ports live in inner layers, implementations in outer layers. Framework types must not leak into Use Cases or Entities. Domain error types live in Entities / Use Cases; infrastructure exceptions are converted to domain errors at the boundary. Prefer explicit `Result` / `Either` over thrown exceptions where the language supports it.

Agent files (`~/.claude/agents/*.md`) contain the detailed per-layer rules — they override this summary on conflict.

## Testing

IMPORTANT: Follow **BDD + Detroit school (classicist) TDD**. Use real objects for any module you own; reserve mocks for collaborators outside your control (DB, network, filesystem, clock, random, external APIs).

The full testing rulebook — Fake / Stub / Boundary Mock taxonomy, the per-layer allowed-doubles table, unit vs. integration responsibilities, the performance-vs-principle ordering, and the review severity matrix — lives in `~/.claude/guidelines/testing.md`. It is **not** inlined here to keep this file short.

`architect`, `developer`, and `code-reviewer` MUST read `~/.claude/guidelines/testing.md` before any task that involves tests or test design. Language-specific test layout conventions live in the per-language guideline files (e.g. `~/.claude/guidelines/rust.md`) and override `testing.md` on conflict.

## Language-Specific Guidelines

Per-language conventions live under `~/.claude/guidelines/<language>.md` and override general guidance on conflict. They are loaded on demand by the agents (via `Read`) rather than inlined here, so this file stays short.

- Rust → `~/.claude/guidelines/rust.md`
- (Add a new file per language as needed.)

All agents (`architect`, `developer`, `code-reviewer`) MUST read the relevant language file before starting work in that language.

## Git Operations

IMPORTANT: Git operations are owned entirely by the user. Do not execute or propose any state-modifying git command — not even to ask for approval.

- Never run: `commit`, `push`, `merge`, `rebase`, `reset`, `checkout -b`, branch/tag create/delete, `stash`, `cherry-pick`, etc.
- Never suggest "shall I commit this?" or stage changes in anticipation of a commit.
- Read-only commands are allowed freely: `git status`, `git diff`, `git log`, `git show`, `git blame`.
- When work is complete, just report what changed and stop. The user will commit themselves.
