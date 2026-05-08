# Global Preferences

## Language & Documentation Policy

- Chat responses to the user: **Japanese**.
- Code, identifiers, and code comments: **English**.
- Design documents (`docs/design/**`), PR documents (`docs/pr/**`), and ADRs (`docs/adr/**`): **Japanese**. Code snippets inside them stay in English.
- Agent definition files (`~/.claude/agents/**.md`): **English**.
- **Japanese prose quality** (chat + Japanese documents — PR / design / ADR). The goal is "write in Japanese", not "translate from English". Four sub-rules:
  - **No JP/EN code-mixing**. Code identifiers (file paths, function / type / crate / module / env-var names) stay native inside backticks; everything else flows in Japanese. When citing a section heading from an English rule file, write 「日本語の説明 (`English heading`)」 — never the reverse. Generic-term substitutions: "smell" → アンチパターン, "top-level bullet" → 最上位の箇条書き, "code identifier" → 識別子, "cross-cutting" → 横断的な, "Bad / Good" → 悪い例 / 良い例.
  - **Use established katakana loanwords for tech terms** rather than coining kanji translations. `port` → ポート (not 接続点), `placeholder` → プレースホルダ (not 仮置き), `workspace` → ワークスペース, `shim` → シム, `composition root` → コンポジションルート, `scope creep` → スコープクリープ, `boilerplate` → ボイラープレート, `fixture` → フィクスチャ. Decision rule: if the industry uses the katakana form in modern Japanese tech writing, use it; if no settled Japanese form exists, default to katakana over a forced kanji translation.
  - **Do not coin new kanji compounds**. If no idiomatic Japanese term exists for a concept, use a descriptive verb phrase OR keep the English term in backticks with a one-line gloss on first mention. Bad: 「依存集約点」「組み立て中枢」「過渡的な置き場」「状態保持機構」. Good: 「依存を一元定義する場所」, 「`composition root` (依存の組み立てを行う起点)」, 「移行期間中のコードの置き場」, 「状態を保持する仕組み」.
  - **Avoid direct-translation syntax**. Calques to rewrite: 「〜することが可能」 → 「〜できる」, 「〜が行われる」 → active voice, 「〜の導入を実施した」 → 「〜を導入した」, 「〜について検討する」 → 「〜を検討する」, 「〜という形で」 → usually drop. After drafting, re-read and rewrite any sentence whose English shape is still visible.

## Development Workflow (MANDATORY)

IMPORTANT: Development work is routed onto one of three execution paths. Pick the path BEFORE invoking any agent. When in doubt between two adjacent paths, choose the heavier one.

**Path A — Direct (no agents; main conversation handles it)**:

- Trivial edits: typo fixes, comment updates, config value tweaks.
- Read-only investigation: answering questions, explaining code, `git status` / `git diff` / `git log`.
- Agent definition maintenance itself (editing files under `~/.claude/agents/` and `~/.claude/rules/`).

**Path B — Lightweight (`developer` + `code-reviewer` only)**: small, scoped changes that meet ALL trigger criteria in the "Lightweight Path (Path B)" section below. Skips `architect`, `pr-writer`, `pr-reviewer`, design doc, PR doc, and task decomposition.

**Path C — Full Orchestration Loop (all five agents)**: the default for any non-trivial change that does not qualify for Path A or Path B. Path C is structured into three phases — design, per-task implementation loop, and PR aggregation. Detailed in the "Orchestration Loop (Path C, MANDATORY)" section below.

Agents and their responsibilities:

1. **architect** — Design phase. Produces the feature-wide design document including a **Task Decomposition** (flat list of atomic tasks with ID, scope, AC, dependencies) and **port-level docstring drafts only**. Does NOT write PR documents, does NOT draft entity/use-case docstrings, does NOT decide PR aggregation, does NOT write implementation code.
2. **developer** — Implementation phase. Implements **one task at a time** per invocation, scoped to that task's entry in the design document's Task Decomposition. Writes tests and code across all Clean Architecture layers using BDD + Detroit-school TDD (Red → Green → Refactor). Writes docstrings per `~/.claude/rules/docstrings.md`; for ports, transcribes the draft from the design doc and refines. Does NOT touch any PR document.
3. **pr-writer** — PR authoring phase. Invoked when the main conversation aggregates one or more completed tasks into a PR. Creates `docs/pr/<feature>/<N>-<aggregation>.md` from scratch — there is no pre-filled skeleton. Fills ALL sections (背景・目的 / スコープ / 受け入れ基準 / 依存PR / 関連ドキュメント / 変更内容 / 設計からの変更点 / テスト / 影響範囲・注意点) per `~/.claude/rules/pr-style.md`, grounded in the design doc, the bundled task list, and the cumulative diff.
4. **code-reviewer** — Code review phase. Invoked per task (Phase 2) — reviews the task's code changes for architecture compliance, dependency health, scope adherence (boundary = the task entry in the design doc), and business application concerns. Does NOT review PR documents and does NOT modify code.
5. **pr-reviewer** — PR document review phase. Invoked per aggregation (Phase 3) — independently reviews `docs/pr/<feature>/<N>-<aggregation>.md` for style compliance against `~/.claude/rules/pr-style.md` AND factual consistency against the bundled task list, the cumulative diff, and the design doc. Does NOT review code quality and does NOT modify the PR document.

### Lightweight Path (Path B)

For small, scoped changes the main conversation invokes ONLY `developer` and `code-reviewer` — `architect`, `pr-writer`, `pr-reviewer`, the design document, the PR document, and task decomposition are all skipped.

**Trigger criteria — ALL must hold**:

- Touches 1–3 files.
- Single conceptual change (one bug fix, one internal refactor, one small addition).
- No new public API surface: no new `pub` function / trait / type signature, no new port, no new use case, no new error variant exposed across layers.
- No new external dependency.
- No architectural boundary moved (no port relocation, no layer reshuffle).

If any criterion fails, fall back to Path C. Typical Path B work: bug fix scoped to one module, internal refactor of an existing function, single test or fixture addition, dependency version bump (no new dep), docstring corrections, error-message wording changes.

**Reduced flow**:

1. **developer** → implements the change via TDD (Red → Green → Refactor). The main conversation passes the change description directly in the invocation prompt; `developer` does NOT look for `docs/design/<feature>.md` or a PR skeleton (none exists). Reports the modified file list at hand-off. Does NOT create or modify any document under `docs/`.
2. **code-reviewer** → grades the code, tests, docstrings, dependencies, and scope adherence against the change description. Findings route to `developer`.
3. **Fix loop** — if `code-reviewer` returns any 🔴 blocker (or any 🟡 the user has not explicitly deferred), re-invoke `developer`, then re-run `code-reviewer`. Exit when zero 🔴 remain.

**Reduced Definition of Done**: items 1, 1a, 1b, and the `pr-reviewer` clause of item 8 in the Definition of Done do NOT apply on Path B. All other items still apply (test-first, task runner green, docstrings on any new/changed public API, function size ≤ 50 lines, no commented-out code, modified file list reported, `code-reviewer` passed).

**Scope-creep escape hatch**: If during Path B work the change grows beyond the trigger criteria (e.g., the refactor turns out to need a new port or a new use case), STOP, report the scope creep to the user, and switch to Path C — start over with `architect` rather than continuing on Path B.

### Task Decomposition (MANDATORY)

`architect` decomposes every non-trivial feature into **Tasks** — atomic work units that `developer` consumes one at a time. Tasks are NOT required to be end-to-end mergeable; PR-level aggregation is decided by the main conversation in Phase 3, not by `architect`.

**Task properties**:

- Atomic enough that one TDD Red→Green→Refactor cycle completes it.
- Each task carries: ID (`T-1`, `T-2`, ...), one-sentence scope, one or more acceptance criteria (`AC-N`), and explicit task-level dependencies (e.g., `T-3 blocked by T-1`).
- Sized qualitatively: typically ≤ 1 conceptual change and ≤ 3 modified files per task. If a proposed task clearly exceeds this, split it before handing off.
- `developer` implements exactly one task per invocation. Future tasks are ignored even if visible from the current code path.

**Documented in the design document** under `## タスク分解` — owned by `architect`. There is **no per-task PR skeleton**: `architect` does not create or pre-fill any file under `docs/pr/`. PR documents are produced by `pr-writer` only when an aggregation is triggered (see Phase 3 below).

**Documentation directory layout (MANDATORY)**: Design docs are flat (one file per feature). PR docs are grouped under a feature-named directory and numbered by aggregation order (PR sequence within the feature), not by task. ADRs remain flat at `docs/adr/` because they are cross-cutting.

```
docs/
├── design/
│   └── <feature>.md                  # design + Task Decomposition + port docstring drafts
├── pr/<feature>/
│   ├── 1-<aggregation-name>.md       # one file per PR aggregation; created by pr-writer
│   ├── 2-<aggregation-name>.md       # ...
│   └── ...
└── adr/
    └── NNNN-<kebab-title>.md         # cross-cutting ADRs (unchanged)
```

PR files use the PR sequence number as a prefix (`1-`, `2-`, ...). `<aggregation-name>` is a short kebab-case descriptor of what the PR ships. The feature name is implied by the directory and is NOT repeated in the file name. PR files are created at aggregation time, not upfront.

### Orchestration Loop (Path C, MANDATORY)

For every non-trivial change that does NOT qualify for Path A or Path B, the main conversation MUST execute the loop end-to-end. Path C has three phases — Design → Per-Task Implementation Loop → Aggregation Gate + Per-PR Loop. Phases run linearly; sub-loops repeat until convergence. Except for the **Task Plan Report** checkpoint (which only blocks when `architect` flags ambiguity), do not pause to ask the user between phases.

#### Phase 1 — Design

1. **architect** → produces design artifacts:
   - Creates `docs/design/<feature>.md` with: clarified requirements, bounded context, use case list, port signatures (each annotated with placement layer), error type hierarchy, trade-off analysis, **port-level docstring drafts only**, and the **Task Decomposition** section (flat list of tasks with ID, scope, AC, dependencies).
   - Does NOT create any file under `docs/pr/`. Does NOT draft entity/use-case docstrings. Does NOT decide PR aggregation. Does NOT write implementation code.
2. **Task Plan Report** → the main conversation reports the task list to the user (task IDs, scope summaries, dependencies, recommended order). Proceed directly to Phase 2 UNLESS `architect` explicitly flags ambiguity (multiple plausible decompositions, unclear ordering, sensitive boundary) — in which case wait for explicit user feedback. The user may always intervene to revise the plan, but the default path no longer pauses.

#### Phase 2 — Per-Task Implementation Loop

For each task in dependency order (or in parallel when dependencies allow):

1. **developer** → implements the current task via TDD. Reads `docs/design/<feature>.md` (whole-feature context) AND the task's entry in the Task Decomposition section. Implements only what that task's scope + AC require — future tasks are ignored. Writes docstrings per `~/.claude/rules/docstrings.md`; for ports, transcribes the architect's draft and refines it. Reports the modified file list AND any deviation from the design with rationale. Does NOT touch any PR document.
2. **code-reviewer** → grades the code, tests, docstrings, dependencies, and scope adherence (boundary = the task entry in the design doc). Findings route to `developer`. Returns findings categorized as 🔴 blocker / 🟡 suggestion / 💭 nit.
3. **Task fix loop** — if `code-reviewer` returns any 🔴 blocker, OR any 🟡 suggestion the user has not explicitly deferred, re-invoke `developer`, then re-run `code-reviewer`. Exit when zero 🔴 remain and all non-deferred 🟡 are addressed. The task is then complete and pending aggregation.

The per-task loop is lightweight: no PR document is touched, neither `pr-writer` nor `pr-reviewer` is invoked. Phase 2 may execute many tasks in succession before Phase 3 fires.

#### Phase 3 — Aggregation Gate and Per-PR Loop

The main conversation decides when to bundle one or more completed (task-fix-loop-cleared) tasks into a PR. **Trigger an aggregation when ANY of the following hold**:

- The completed tasks together deliver an observable behavior (a use case reachable from the adapter boundary, a CLI command, a visible UI flow).
- The user explicitly signals to ship.
- The pending bundle is approaching ~5 tasks, or the cumulative diff across the bundle has reached ~5 modified files / ~2 distinct concepts — aggregate now before the bundle grows further.

For each aggregation:

1. **pr-writer** → creates `docs/pr/<feature>/<N>-<aggregation>.md` from scratch (no skeleton exists). Reads `docs/design/<feature>.md`, the list of tasks in this aggregation (their entries from the Task Decomposition section), and the cumulative diff. Fills ALL sections (背景・目的 / スコープ / 受け入れ基準 / 依存PR / 関連ドキュメント / 変更内容 / 設計からの変更点 / テスト / 影響範囲・注意点) per `~/.claude/rules/pr-style.md`. Reports the file path and any mismatch surfaced during self-check.
2. **pr-reviewer** → grades the PR document on two axes: style (against the `pr-style.md` Severity Matrix) and factual consistency (against the bundled task list, the cumulative diff, and `docs/design/<feature>.md`). Findings route to `pr-writer` (prose), `architect` (design drift / task-list drift), or `developer` (when a PR-doc inconsistency reflects the implementation being out of task scope).
3. **PR fix loop** — re-invoke whichever agent owns the change and re-run `pr-reviewer` until zero 🔴 remain and all non-deferred 🟡 are addressed. If `architect` revises the Task Decomposition during this loop (because the implementation deviated from the design in a way that requires the design to be updated), re-run `pr-reviewer` after the design update.
4. The aggregation is then ready for the user to review and merge. The next aggregation re-enters Phase 3 with whatever tasks Phase 2 has completed since.

The overall feature is complete when every task has exited its task fix loop AND every aggregation has exited its PR fix loop.

When invoking the next agent, always pass the previous agent's output (design artifacts, task IDs in scope, modified file list, or review findings) as context — never ask the next agent to re-discover what the previous one already produced.

The user is consulted **only** at these points (never between phases of the loop itself):

- **Task Plan Approval** — only when `architect` explicitly flags decomposition ambiguity (Phase 1 step 2). The default path proceeds without a user gate.
- **Aggregation timing** — when none of the auto-triggers above clearly fire and Phase 2 has produced multiple completed tasks, ask the user whether to aggregate now or continue.
- **Dependency approval** (per the Dependency Approval Process below).
- **Ambiguous requirements** that `architect` cannot resolve from the available context.
- **Non-convergence escalation** — if either fix loop has run three times without converging, stop and escalate with a summary of what is blocking convergence.

## Definition of Done (ALL items MUST be satisfied)

A development task is NOT complete until every item below is true. The `developer` agent MUST verify this list before declaring work finished. `code-reviewer` MUST reject any hand-off that skips code-side items; `pr-reviewer` MUST reject any hand-off that skips PR-document items.

On the Lightweight Path (Path B) the design / PR-document items are skipped — see "Lightweight Path (Path B)" above for the reduced checklist.

1. **Design artifacts exist**: `docs/design/<feature>.md` written/updated with clarified requirements, acceptance criteria, port-level docstring drafts, and a Task Decomposition section. ADRs created when applicable.
1a. **Task plan reported**: The task list (IDs, scope summaries, dependencies, order) has been reported to the user. User approval is required only when `architect` flagged decomposition ambiguity.
1b. **PR documents exist per aggregation**: For each aggregation triggered in Phase 3, `docs/pr/<feature>/<N>-<aggregation>.md` exists and is fully populated by `pr-writer` (all sections — there is no `architect`-pre-filled portion). Style compliance against `~/.claude/rules/pr-style.md` and factual consistency against the bundled task list, the cumulative diff, and the design document are confirmed by `pr-reviewer`.
2. **Test-first**: Every new behavior was introduced via a failing test before production code (see `~/.claude/rules/testing.md`).
3. **Task runner green**: Full test + lint + build via the project's task runner (Rust: `cargo make test` / `cargo make lint` / `cargo make build` — never bare `cargo test`). Zero warnings.
4. **Docstrings present**: All public API elements have English docstrings. Port docstrings start from the draft in the design document and are refined against the implementation.
5. **Function size**: No function exceeds 50 lines.
6. **No commented-out code, no orphan TODO/FIXME**: TODO/FIXME only if linked to an issue/ticket.
7. **Modified file list reported**: `developer` reports the full list of created/modified files at hand-off.
8. **Independent reviews passed**: BOTH `code-reviewer` (code / tests / docstrings / dependencies / scope adherence) AND `pr-reviewer` (PR document style + factual consistency) reviewed the change; all 🔴 blockers resolved; 🟡 suggestions addressed or explicitly deferred with rationale.

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

Detailed rules live in external files so this document stays short. All agents (`architect`, `developer`, `pr-writer`, `code-reviewer`, `pr-reviewer`) MUST `Read` the relevant files before starting work. Language-specific files override general guidance on conflict.

- **Testing** (every task): `~/.claude/rules/testing.md` — BDD + Detroit school rules, Fake / Stub / Boundary Mock taxonomy, per-layer allowed-doubles table, unit vs. integration responsibilities, review severity matrix.
- **Docstrings** (tasks touching public API): `~/.claude/rules/docstrings.md` — required structure, prohibited patterns, port-trait specifics, severity matrix.
- **PR style** (every task that touches `docs/pr/**`): `~/.claude/rules/pr-style.md` — Core Rule (Bullets First), Formatting Constraints, Per-Section Style, and the Severity Matrix used by `pr-reviewer`. Read by `pr-writer` (composition) and `pr-reviewer` (enforcement).
- **Design doc style** (every task that touches `docs/design/**`): `~/.claude/rules/design-doc-style.md` — Required Sections (in order), Per-Section Style, and a Severity Matrix used by `architect` for self-check. Independent of `pr-style.md`; rules are restated where they appear identical, since the two files address different audiences and lifecycles.
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

Every rule file that a reviewer agent (`code-reviewer` or `pr-reviewer`) consults for grading (currently `testing.md`, `docstrings.md`, `architecture.md`, `pr-style.md`) MUST expose its severity matrix at the **bottom of the file under a `## Severity Matrix` heading** (consistent name and location). The reviewer agents rely on a predictable anchor — do not scatter severity rules mid-document.

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
