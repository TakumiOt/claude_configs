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

1. **architect** — Design phase. Produces the feature-wide design document, decomposes the feature into **Vertical Slices**, and creates a PR skeleton per slice (scope, acceptance criteria, dependencies, diff budget). Does NOT write implementation code or the PR prose sections.
2. **developer** — Implementation phase. Implements **one slice at a time**, scoped to the current PR skeleton's acceptance criteria. Writes tests and code across all Clean Architecture layers using BDD + Detroit-school TDD (Red → Green → Refactor). Does NOT write the PR prose sections.
3. **pr-writer** — PR authoring phase. Fills the **prose sections** (変更内容 / 設計からの変更点 / テスト / 影響範囲・注意点) of the current slice's PR skeleton, which already has scope and acceptance criteria filled in by `architect`. Writes feature-level prose summaries grounded in the design document and the diff — no file-by-file enumeration, no test-function-name lists.
4. **code-reviewer** — Review phase. Independently reviews the current slice's code changes for architecture compliance, dependency health, slice-size compliance, and business application concerns, and fact-checks the slice's PR document against the implementation. Does NOT modify code or rewrite the PR document.

### Vertical Slice Decomposition (MANDATORY)

Large changes must be broken down by `architect` into **Vertical Slices** — independently reviewable, end-to-end-thin PRs. Each slice:

- Has its own `docs/pr/<feature>-<slice>.md` skeleton, authored by `architect` during the design phase.
- Has a **Diff budget**: soft target **400 lines**, hard limit **600 lines** of production + test code (**docstring lines are excluded** from the count).
- Declares **dependencies** on other slices (which slices must be merged first). Slices with no unmet dependencies may execute in parallel; by default assume sequential.
- Is scoped so the `developer` implements only what that skeleton describes — not the rest of the feature.

### Orchestration Loop (MANDATORY)

For every non-trivial change, the main conversation MUST execute the following loop end-to-end. Except for the **Slice Plan Approval** checkpoint below, do not pause to ask the user between phases.

1. **architect** → produces design artifacts:
   - Creates `docs/design/<feature>.md` (feature-wide: use cases, ports, error types, test perspectives, ADRs as needed).
   - Decomposes the feature into Vertical Slices per the rules above.
   - Creates one `docs/pr/<feature>-<slice>.md` skeleton per slice, with scope, acceptance criteria, dependencies, and diff budget filled in.
   - Does NOT fill the prose sections of the PR skeletons — that is the `pr-writer`'s responsibility after each slice is implemented.
2. **Slice Plan Approval (user checkpoint)** → the main conversation reports the slice list to the user (slice names, scope summaries, dependencies, order) and waits for explicit approval before proceeding. Revise per feedback and re-confirm if the user requests changes.
3. **Per-slice loop** — for each approved slice, in dependency order (or in parallel when dependencies allow):
   1. **developer** → implements the current slice via TDD. Reads `docs/design/<feature>.md` (whole-feature context) AND the current slice's PR skeleton (the implementation scope). Implements only what the skeleton's scope + acceptance criteria require. Satisfies the Definition of Done. Reports the full modified-file list AND any deviations from the design document with rationale (input for `pr-writer`). Does NOT touch any PR document.
   2. **pr-writer** → fills the prose sections of the current slice's `docs/pr/<feature>-<slice>.md`:
      - Reads the design document, the slice's PR skeleton (already filled with scope / acceptance criteria by `architect`), the modified-file list, and the diff.
      - Fills 変更内容 / 設計からの変更点 / テスト / 影響範囲・注意点 per its own style rules. Does NOT rewrite scope / acceptance criteria / dependencies — those are `architect`-owned.
      - Reports the file path and any mismatches between design and implementation surfaced during self-check.
   3. **code-reviewer** → independently reviews the slice's code and PR document, returning findings categorized as 🔴 blocker / 🟡 suggestion / 💭 nit. Each finding is routed to either `developer` (code/tests/docstrings/dependencies/slice-size) or `pr-writer` (PR document factual consistency). The reviewer does NOT grade PR prose style — that is `pr-writer`'s domain.
   4. **Fix loop**: If code-reviewer returns any 🔴 blocker, OR any 🟡 suggestion that the user has not explicitly deferred:
      - Route code-side findings to `developer`. If code changes occur, re-invoke `pr-writer` after `developer` finishes so the PR document stays in sync.
      - Route PR-document-side findings to `pr-writer`.
      - Then re-run step 3.3.
   5. The per-slice loop exits only when code-reviewer returns **zero 🔴 blockers** and all non-deferred 🟡 items are addressed. The slice is then ready for the user to review and merge.
4. The overall task is complete when every slice has exited its per-slice loop. The user handles all git / merge operations between slices.

When invoking the next agent, always pass the previous agent's output (design artifacts, slice skeleton path, modified file list, or review findings) as context — never ask the next agent to re-discover what the previous one already produced.

The user is consulted **only** at these points (never between phases of the loop itself):

- **Slice Plan Approval** (step 2 of the Orchestration Loop).
- **Dependency approval** (per the Dependency Approval Process below).
- **Ambiguous requirements** that the architect cannot resolve from the available context.
- **Non-convergence escalation**: if the per-slice loop has executed step 3.3 → step 3.4 → step 3.3 three times without converging, stop and escalate to the user with a summary of what is blocking convergence.

## Definition of Done (ALL items MUST be satisfied)

A development task is NOT complete until every item below is true. The `developer` agent MUST verify this list before declaring work finished. The `code-reviewer` agent MUST reject any hand-off that skips these items.

1. **Design artifacts exist**: `docs/design/<feature>.md` written/updated with acceptance criteria and a Vertical Slice Decomposition (one slice per PR). ADRs created when applicable.
1a. **Slice plan approved**: The user has approved the slice list (names, scopes, dependencies, order) before any `developer` work began.
1b. **PR documents exist per slice**: `docs/pr/<feature>-<slice>.md` exists for every slice. Scope / acceptance criteria / dependencies / diff budget filled by `architect`; prose sections (変更内容 / 設計からの変更点 / テスト / 影響範囲・注意点) filled by `pr-writer` after implementation. Factual consistency with the implementation confirmed by `code-reviewer`.
1c. **Slice diff budget respected**: Each slice's diff stays within the soft target (400 lines) or has an explicit rationale if between 400 and 600. Exceeding the 600-line hard limit (production + test lines, **docstring lines excluded**) is a 🟡 finding from `code-reviewer` that must be addressed or explicitly deferred by the user. The **single canonical counter** is `~/.claude/scripts/diff-budget.sh` (invoked with the project's base branch as argument, defaulting to `main`). Every agent that needs a diff-line count MUST invoke this script and report the `counted` / `verdict` values from its output — do not re-derive the count via `git diff | wc -l` or other ad-hoc methods, as those will disagree on generated-file and docstring exclusions.
2. **Test-first**: Every new behavior was introduced via a failing test before production code (see `~/.claude/rules/testing.md`).
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

- **Testing** (every task): `~/.claude/rules/testing.md` — BDD + Detroit school rules, Fake / Stub / Boundary Mock taxonomy, per-layer allowed-doubles table, unit vs. integration responsibilities, review severity matrix.
- **Docstrings** (tasks touching public API): `~/.claude/rules/docstrings.md` — required structure, prohibited patterns, port-trait specifics, severity matrix.
- **Language** (per project): `~/.claude/rules/<language>.md` — test layout, task runner, error idioms.
  - Rust → `~/.claude/rules/rust.md`
  - (Add a new file per language as needed.)

## Rules Directory Governance (`~/.claude/rules/`)

The `~/.claude/rules/` directory is the Claude Code–native user-level rules store (see the official Memory docs). The governance below keeps it useful without exploding every session's context budget.

### 1. File size + `paths:` discipline (context hygiene)

- **Soft target**: ≤ 200 lines per rule file.
- **Hard ceiling**: ≤ 400 lines per rule file.
- Any rule file exceeding 400 lines MUST declare a `paths:` frontmatter so it does not auto-load into every session. Unconditional (no `paths:`) rules must stay small.
- When a rule approaches 400 lines, it is almost always a sign the scope is too broad — split it (e.g., extract a language-specific sub-rule) before raising the ceiling.

### 2. Boundary between `CLAUDE.md`, `rules/`, and `agents/`

Each file has exactly one responsibility; content MUST NOT drift across boundaries.

- **`CLAUDE.md`** — Top-level orchestration only: who runs in which phase, Definition of Done, mandatory workflows. Target ≤ 300 lines. Detailed principles are NOT inlined here; they live in `rules/`.
- **`rules/`** — Principles: what constitutes correct design / implementation / testing / documentation. Does NOT describe workflow or role responsibilities.
- **`agents/`** — Roles: what each agent reads, produces, and hands off. Each agent links to the `rules/` files it depends on, rather than re-stating them.

When updating any of the three, verify the change belongs to that file's responsibility. Workflow content slipping into `rules/`, or detailed principles slipping into `agents/`, is drift to be corrected.

### 3. Severity matrix placement

Every rule file that `code-reviewer` consults for grading (currently `testing.md`, `docstrings.md`, `architecture.md`) MUST expose its severity matrix at the **bottom of the file under a `## Severity Matrix` heading** (consistent name and location). `code-reviewer` relies on a predictable anchor — do not scatter severity rules mid-document.

### 4. Conflict resolution between overlapping rules

When two rule files address the same concern, state the precedence explicitly in the affected files' opening matter. The convention is **more-specific wins**:

- Language-specific rule > general architecture rule (Rust newtype mechanics in `rust.md` win over generic port-placement wording in `architecture.md`).
- Review-severity matrix in a topic file (e.g., `testing.md`) > generic severity mapping in `architecture.md`.
- Document the winner at the top of the more-specific rule file, so readers do not have to guess.

### 5. Rule-change checklist (prevents stale references)

When adding, renaming, splitting, or retiring a rule file, perform all of the following before declaring the change done:

1. `grep -r '<old-rule-path>' ~/.claude` — update every reference in `CLAUDE.md`, `agents/**/*.md`, other rules files, `.gitignore`, and `scripts/**`.
2. Verify the `paths:` frontmatter still reflects when the rule is relevant (not narrower, not broader).
3. Check that `CLAUDE.md`'s "Guidelines to Read" section lists current rule files accurately.
4. If the rule had a Severity Matrix, confirm the matrix is preserved (or explicitly removed with rationale) after the change.
5. Confirm the file size is within the ceilings from §1; split if not.

### 6. Language

Rule files are written in **English** (matching `~/.claude/agents/*.md`). Code identifiers and snippets stay in their native language. The user chat remains Japanese per the global Language Policy above.
