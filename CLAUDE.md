# Global Preferences

## Language & Documentation Policy

- Chat responses to the user: **Japanese**.
- Code, identifiers, and code comments: **English**.
- Design documents (`docs/design/**`), PR documents (`docs/pr/**`), and ADRs (`docs/adr/**`): **Japanese**. Code snippets inside them stay in English.
- Agent definition files (`~/.claude/agents/**.md`): **English**.

## Development Workflow (MANDATORY)

IMPORTANT: All development work MUST be delegated to the specialized agents in `~/.claude/agents/`. Do not implement features, write tests, or review code directly in the main conversation.

Exceptions — main conversation may handle directly:

- Trivial edits: typo fixes, comment updates, config value tweaks.
- Read-only investigation: answering questions, explaining code, `git status` / `git diff` / `git log`.
- Agent definition maintenance itself (editing files under `~/.claude/agents/`).

When in doubt, delegate.

Agents and their responsibilities:

1. **architect** — Design phase. Produces use cases, port interfaces, domain error types, ADRs, and trade-off analyses. Does NOT write implementation code or the PR document.
2. **developer** — Implementation phase. Writes tests and code across all Clean Architecture layers using BDD + Detroit-school TDD (Red → Green → Refactor). Does NOT write the PR document.
3. **pr-writer** — PR authoring phase. Owns `docs/pr/<feature>.md` end-to-end. Writes feature-level prose summaries grounded in the design document and the diff — no file-by-file enumeration, no test-function-name lists.
4. **code-reviewer** — Review phase. Independently reviews code changes for architecture compliance, dependency health, and business application concerns, and fact-checks the PR document against the implementation. Does NOT modify code or rewrite the PR document.

### Orchestration Loop (MANDATORY)

For every non-trivial change, the main conversation MUST execute the following loop end-to-end. **Do not pause to ask the user between phases.**

1. **architect** → produces design artifacts:
   - Creates `docs/design/<feature>.md` (detailed design: use cases, ports, error types, test perspectives, ADRs as needed).
   - Does NOT touch `docs/pr/<feature>.md` — that is the `pr-writer`'s responsibility after implementation.
2. **developer** → implements via TDD using the architect's output and satisfies the Definition of Done.
   - Reports the full modified-file list AND any deviations from the design document with rationale (input for `pr-writer`).
   - Does NOT touch `docs/pr/<feature>.md`.
3. **pr-writer** → authors `docs/pr/<feature>.md` from scratch:
   - Reads the design document, the modified-file list, and the diff.
   - Fills every section per its own style rules (feature-level prose for 変更内容, test perspectives in prose for テスト, etc.).
   - Reports the file written and any mismatches between design and implementation it surfaced during self-check.
4. **code-reviewer** → independently reviews the change and the PR document, returning findings categorized as 🔴 blocker / 🟡 suggestion / 💭 nit. Each finding is routed to either `developer` (code/tests/docstrings/dependencies) or `pr-writer` (PR document factual consistency). The reviewer does NOT grade PR prose style — that is `pr-writer`'s domain.
5. **Fix loop**: If code-reviewer returns any 🔴 blocker, OR any 🟡 suggestion that the user has not explicitly deferred:
   - Route code-side findings to `developer`. If code changes occur, re-invoke `pr-writer` after `developer` finishes so the PR document stays in sync.
   - Route PR-document-side findings to `pr-writer`.
   - Then go back to step 4.
6. The loop exits only when code-reviewer returns **zero 🔴 blockers** and all non-deferred 🟡 items are addressed. Only then is the task considered ready for user review.

When invoking the next agent in the loop, always pass the previous agent's output (design artifacts, modified file list, PR document path, or review findings) as context — never ask the next agent to re-discover what the previous one already produced.

The user is consulted **only** at these points (never between phases of the loop itself):

- **Dependency approval** (per the Dependency Approval Process below).
- **Ambiguous requirements** that the architect cannot resolve from the available context.
- **Non-convergence escalation**: if the loop has executed step 4 → step 5 → step 4 three times without converging, stop and escalate to the user with a summary of what is blocking convergence.

## Definition of Done (ALL items MUST be satisfied)

A development task is NOT complete until every item below is true. The `developer` agent MUST verify this list before declaring work finished. The `code-reviewer` agent MUST reject any hand-off that skips these items.

1. **Design artifacts exist**: `docs/design/<feature>.md` written/updated with acceptance criteria. ADRs created when applicable.
1a. **PR document exists**: `docs/pr/<feature>.md` written/updated by the `pr-writer` agent. All sections filled per `pr-writer`'s style rules (feature-level prose, not file lists; test perspectives, not function-name lists). Factual consistency with the implementation confirmed by `code-reviewer`.
2. **Test-first**: Every new behavior was introduced via a failing test before production code (see `~/.claude/guidelines/testing.md`).
3. **Task runner green**: Full test + lint + build via the project's task runner (Rust: `cargo make test` / `cargo make lint` / `cargo make build` — never bare `cargo test`). Zero warnings.
4. **Docstrings present**: All public API elements have English docstrings. Port docstrings start from the draft in the design document and are refined against the implementation.
5. **Function size**: No function exceeds 50 lines.
6. **No commented-out code, no orphan TODO/FIXME**: TODO/FIXME only if linked to an issue/ticket.
7. **Modified file list reported**: `developer` reports the full list of created/modified files at hand-off.
8. **Independent review passed**: `code-reviewer` reviewed the change; all 🔴 blockers resolved; 🟡 suggestions addressed or explicitly deferred with rationale.

## Dependency Approval Process (MANDATORY)

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

## Git Operations

IMPORTANT: Git operations are owned entirely by the user. Do not execute or propose any state-modifying git command — not even to ask for approval. This applies inside the Orchestration Loop as well: no agent stages, commits, or proposes a commit.

- Never run: `commit`, `push`, `merge`, `rebase`, `reset`, `checkout -b`, branch/tag create/delete, `stash`, `cherry-pick`, etc.
- Never suggest "shall I commit this?" or stage changes in anticipation of a commit.
- Read-only commands are allowed freely: `git status`, `git diff`, `git log`, `git show`, `git blame`.
- When work is complete, just report what changed and stop. The user will commit themselves.

## Coding

Size, docstrings, comments, and TODO rules are covered by the Definition of Done — they are not repeated here. Additional rules:

- No speculative features — only build what's needed now.
- Replace, don't deprecate — remove old code outright; git history preserves it.
- Inline comments explain *why*, never *what*.
- When compacting, preserve the list of modified files.

## Architecture & Error Handling

IMPORTANT: Follow Clean Architecture. Layers inward → outward: **Entities → Use Cases → Adapters → Infrastructure**. Dependencies point inward only. Ports live in inner layers, implementations in outer layers. Framework types must not leak into Use Cases or Entities. Domain error types live in Entities / Use Cases; infrastructure exceptions are converted to domain errors at the boundary. Prefer explicit `Result` / `Either` over thrown exceptions where the language supports it.

Agent files (`~/.claude/agents/*.md`) contain the detailed per-layer rules — they override this summary on conflict.

## Guidelines to Read

Detailed rules live in external files so this document stays short. All agents (`architect`, `developer`, `pr-writer`, `code-reviewer`) MUST `Read` the relevant files before starting work. Language-specific files override general guidance on conflict.

- **Testing** (every task): `~/.claude/guidelines/testing.md` — BDD + Detroit school rules, Fake / Stub / Boundary Mock taxonomy, per-layer allowed-doubles table, unit vs. integration responsibilities, review severity matrix.
- **Docstrings** (tasks touching public API): `~/.claude/guidelines/docstrings.md` — required structure, prohibited patterns, port-trait specifics, severity matrix.
- **Language** (per project): `~/.claude/guidelines/<language>.md` — test layout, task runner, error idioms.
  - Rust → `~/.claude/guidelines/rust.md`
  - (Add a new file per language as needed.)
