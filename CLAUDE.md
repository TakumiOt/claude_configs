# Global Preferences

## Language & Documentation Policy

- Chat responses to the user: **Japanese**.
- Code, identifiers, and code comments: **English**.
- Specification documents (`docs/spec/**`), PR documents (`docs/pr/**`), and ADRs (`docs/adr/**`): **Japanese**. Code snippets inside them stay in English.
- Agent definition files (`~/.claude/agents/**.md`): **English**.
- **Japanese prose quality** (chat + Japanese documents — PR / spec / ADR). The goal is "write in Japanese", not "translate from English". Four sub-rules:
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

**Path B — Lightweight (`developer` + `code-reviewer` only)**: small, scoped changes that meet ALL trigger criteria in the "Lightweight Path (Path B)" section below. Skips `architect`, `pr-writer`, `pr-reviewer`, spec doc, PR doc, and task decomposition.

**Path C — Full Orchestration Loop (all five agents)**: the default for any non-trivial change that does not qualify for Path A or Path B. Path C is structured into three phases — design, per-task implementation loop, and PR aggregation. Detailed in the "Orchestration Loop (Path C, MANDATORY)" section below.

Agents and their responsibilities:

1. **architect** — Design phase. Produces and maintains the **living specification (仕様書)** at basic-design granularity: the system-wide `docs/spec/overview/` (全体仕様) and per-capability `docs/spec/<capability>/` directories (cross-cutting technical concerns in `docs/spec/_platform/`), plus standalone Task Decomposition documents at `docs/tasks/<work-name>.md`, where `<work-name>` is a kebab-case descriptor of what the tasks accomplish. Spec documents stay at basic-design granularity — purpose, responsibility, behavior, structure — and never contain type signatures, error-enum definitions, DDL, or docstring drafts (detailed design lives in the code). The architect drafts the spec forward at design time (target state) and reconciles it against the shipped implementation at merge (Phase 3); rationale ("why") lives in ADRs, not the spec. A single feature may touch multiple capabilities and therefore update multiple directories. Does NOT write PR documents, does NOT decide PR aggregation, does NOT write implementation code.
2. **developer** — Implementation phase. Implements **one task at a time** per invocation, scoped to that task's entry in the relevant `docs/tasks/<work-name>.md`. Reads `docs/spec/<capability>/` for the capability the task belongs to, plus any cross-cutting dependencies the task references (e.g. `docs/spec/_platform/`). Writes tests and code across all Clean Architecture layers using BDD + Detroit-school TDD (Red → Green → Refactor). Writes docstrings from scratch per `~/.claude/rules/docstrings.md` (spec documents carry no drafts). Does NOT touch any PR document.
3. **pr-writer** — PR authoring phase. Invoked when the main conversation aggregates one or more completed tasks into a PR. Creates `docs/pr/<feature>/<N>-<aggregation>.md` from scratch — there is no pre-filled skeleton. Fills ALL sections (背景・目的 / スコープ / 受け入れ基準 / 依存PR / 関連ドキュメント / 変更内容 / 仕様からの変更点 / テスト / 影響範囲・注意点) per `~/.claude/rules/pr-style.md`, grounded in **all capability spec directories the bundled tasks touch**, the bundled task list, and the cumulative diff.
4. **code-reviewer** — Code review phase. Invoked per task (Phase 2) — reviews the task's code changes for architecture compliance, dependency health, scope adherence (boundary = the task entry in `docs/tasks/<work-name>.md`), and business application concerns. Does NOT review PR documents and does NOT modify code.
5. **pr-reviewer** — PR document review phase. Invoked per aggregation (Phase 3) — independently reviews `docs/pr/<feature>/<N>-<aggregation>.md` for style compliance against `~/.claude/rules/pr-style.md` AND factual consistency against the bundled task list, the cumulative diff, and **every capability spec directory the bundled tasks touch**. Does NOT review code quality and does NOT modify the PR document.

### Lightweight Path (Path B)

For small, scoped changes the main conversation invokes ONLY `developer` and `code-reviewer` — `architect`, `pr-writer`, `pr-reviewer`, the spec document, the PR document, and task decomposition are all skipped.

**Trigger criteria — ALL must hold**:

- Touches 1–3 files.
- Single conceptual change (one bug fix, one internal refactor, one small addition).
- No new public API surface: no new `pub` function / trait / type signature, no new port, no new use case, no new error variant exposed across layers.
- No new external dependency.
- No architectural boundary moved (no port relocation, no layer reshuffle).

If any criterion fails, fall back to Path C. Typical Path B work: bug fix scoped to one module, internal refactor of an existing function, single test or fixture addition, dependency version bump (no new dep), docstring corrections, error-message wording changes.

**Reduced flow**:

1. **developer** → implements the change via TDD (Red → Green → Refactor). The main conversation passes the change description directly in the invocation prompt; `developer` does NOT look for any spec directory (`docs/spec/<capability>/`) or a PR skeleton (none exists). Reports the modified file list at hand-off. Does NOT create or modify any document under `docs/`.
2. **code-reviewer** → grades the code, tests, docstrings, dependencies, and scope adherence against the change description. Findings route to `developer`.
3. **Fix loop** — if `code-reviewer` returns any 🔴 blocker (or any 🟡 the user has not explicitly deferred), re-invoke `developer`, then re-run `code-reviewer`. Exit when zero 🔴 remain.
4. **Commit & completion report (MANDATORY)** — as soon as the Fix loop exits, the main conversation commits the change (one commit, per "Git Operations") and reports the completion summary to the user. The report includes: the change description (one sentence), the modified file list, a one-line test/lint/build outcome, and any deviation from the original change description (with rationale). No confirmation wait is required; pushing the branch is the user's job per "Git Operations". This is the same step as Phase 2 step 4 in Path C — adapted to Path B's single-task shape.

**Reduced Definition of Done**: items 1, 1a, 1b, 1c, and the `pr-reviewer` clause of item 8 in the Definition of Done do NOT apply on Path B. All other items still apply (test-first, task runner green, docstrings on any new/changed public API, function size ≤ 50 lines, no commented-out code, modified file list reported, `code-reviewer` passed, commit & completion report done).

**Scope-creep escape hatch**: If during Path B work the change grows beyond the trigger criteria (e.g., the refactor turns out to need a new port or a new use case), STOP, report the scope creep to the user, and switch to Path C — start over with `architect` rather than continuing on Path B.

### Task Decomposition (MANDATORY)

`architect` decomposes every non-trivial feature into **Tasks** — atomic work units that `developer` consumes one at a time. **Two granularities, deliberately distinct**: a **Task** is atomic (one TDD Red→Green→Refactor cycle) and is NOT required to be end-to-end mergeable — it may leave the codebase in an intermediate state; a **PR** is a **vertical slice** that MUST be independently verifiable by exercising the running system (see Phase 3). PR-level aggregation is decided by the main conversation in Phase 3, not by `architect`. `architect` still orders tasks and shapes dependencies so they compose into verifiable vertical slices — the earliest possible slice should reach an exercisable end (a UI flow, a CLI command, an endpoint or use case wired through the composition root), rather than building every foundation layer before anything is runnable.

**Task properties**:

- Atomic enough that one TDD Red→Green→Refactor cycle completes it.
- Each task carries: a one-sentence scope, one or more acceptance criteria, and explicit task-level dependencies. **No identifiers** — neither tasks, ACs, use cases, nor ports carry numeric IDs. References across the spec directory (and into the PR document) use the natural identifier of the thing being referenced: function name for use cases (`IngestCountingEvents`), trait name for ports (`CountingEventRepository`), scope sentence for tasks ("the task that defines the `Clock` port"). Cross-capability dependencies cite the other directory by name (e.g., "`_platform` の `Clock` ポート定義タスク").
- Sized qualitatively: typically ≤ 1 conceptual change and ≤ 3 modified files per task. If a proposed task clearly exceeds this, split it before handing off.
- `developer` implements exactly one task per invocation. The main conversation passes the relevant task row (the scope sentence and its AC entries) to the developer in the invocation prompt. Future tasks are ignored even if visible from the current code path.

**Documented in a standalone `docs/tasks/<work-name>.md`** — one per coherent unit of work, the filename a kebab-case descriptor of what the tasks accomplish (e.g. `clock-and-id-generator-implementation.md`), NOT a crate name. Owned by `architect`, separate from the spec documents and not governed by `spec-style.md`. There is **no per-task PR skeleton**: `architect` does not create or pre-fill any file under `docs/pr/`. PR documents are produced by `pr-writer` only when an aggregation is triggered (see Phase 3 below).

**Documentation directory layout (MANDATORY)**: The living specification lives under `docs/spec/`, indexed by **capability**. A system-wide `overview/` directory holds the 全体仕様; each capability gets its own directory; cross-cutting technical concerns (infrastructure, shared kernel) live in `_platform/`. Task Decomposition lives under `docs/tasks/`, one file per coherent unit of work with the filename describing what the tasks accomplish, separate from the spec documents. PR docs remain grouped by **feature** (the deliverable unit). ADRs remain flat at `docs/adr/` because they are cross-cutting — and per the 時計分離 rule they are the home of all "why" (rationale / trade-offs).

```
docs/
├── spec/                                # living specification (canonical, continuously maintained)
│   ├── README.md                        # spec-tree map: structure, 時計分離 policy, capability list
│   ├── overview/                        # system-wide 全体仕様
│   │   ├── README.md                    # purpose, actors, capability list, 収録方針, ToC
│   │   └── <use-cases/architecture>.md
│   ├── <capability-A>/                  # one directory per capability
│   │   ├── README.md                    # entry point: purpose, scope, 収録方針, ToC
│   │   └── <behavior/data-and-constraints/implementation-map>.md
│   └── _platform/                       # cross-cutting technical concerns (infra, kernel)
├── tasks/
│   ├── README.md                        # entry point: what this dir holds (Task Decomposition files), naming, ToC
│   └── <work-name>.md                   # Task Decomposition; filename describes the work (NOT a spec document)
├── pr/
│   ├── README.md                        # entry point: PR docs grouped by feature, naming, ToC of features
│   └── <feature>/
│       ├── README.md                    # this feature's PRs in sequence, one line each
│       ├── 1-<aggregation-name>.md      # one file per PR aggregation; created by pr-writer
│       └── 2-<aggregation-name>.md      # ...
└── adr/
    ├── README.md                        # entry point: what an ADR is, status lifecycle, chronological index
    └── NNNN-<kebab-title>.md            # cross-cutting ADRs; home of all rationale ("why")
```

**README everywhere (MANDATORY)**: Every directory under `docs/` — `spec/` and its subdirectories, `tasks/`, `pr/` and each `<feature>/`, and `adr/` — carries a Japanese `README.md` entry point stating 目的・責務, 収録方針 (what documents belong there and what does NOT), and a 目次 (relative links to the directory's contents). Owners: `architect` for `spec/` / `tasks/` / `adr/`; `pr-writer` for `pr/` and each `<feature>/`. The `docs/adr/README.md` is the single chronological ADR index — the 全体仕様 links to it rather than keeping a separate index.

Spec directory rules (full detail in `~/.claude/rules/spec-style.md`):

- The spec is a **living document** describing what the system does now, at basic-design granularity. Detailed design (type signatures, error-enum definitions, DDL, docstrings) lives in the code; rationale / trade-offs live in ADRs.
- The architect drafts the spec forward at design time (target state) and reconciles it at merge so the spec on a branch matches that branch's behavior.
- Every directory under `docs/spec/` MUST contain a Japanese `README.md` entry point stating 目的・責務, 収録方針 (what documents belong there), and a 目次. The file set follows the per-spec-kind templates in `~/.claude/rules/spec-style.md` (全体仕様 / 機能領域仕様 / 横断・技術仕様).
- `docs/spec/overview/` holds the 全体仕様 and is updated whenever a feature changes system-level structure.
- Task Decomposition lives in `docs/tasks/<work-name>.md` — a standalone file with its own format (`~/.claude/agents/architect.md`), not part of the spec templates and not governed by `spec-style.md`.
- Cross-directory references use relative Markdown links (e.g. `../_platform/README.md`).

PR files use the PR sequence number as a prefix (`1-`, `2-`, ...). `<aggregation-name>` is a short kebab-case descriptor of what the PR ships. The feature name is implied by the directory and is NOT repeated in the file name. PR files are created at aggregation time, not upfront.

### Orchestration Loop (Path C, MANDATORY)

For every non-trivial change that does NOT qualify for Path A or Path B, the main conversation MUST execute the loop end-to-end. Path C has three phases — Design → Per-Task Implementation Loop → Aggregation Gate + Per-PR Loop. Phases run linearly; sub-loops repeat until convergence. Except for the **Task Plan Report** checkpoint (which only blocks when `architect` flags ambiguity) and the **aggregation hand-off** (Phase 3 step 5, where the user takes over for push and PR creation), do not pause to ask the user between phases.

#### Phase 1 — Design

1. **architect** → drafts the spec forward (target state) for **every capability the feature touches**:
   - Per-capability: creates or updates `docs/spec/<capability>/` with purpose / scope / behavior / data-and-constraints / implementation-map, following the per-spec-kind templates in `~/.claude/rules/spec-style.md`. Documents stay at basic-design granularity and never contain type signatures, error-enum definitions, DDL, or docstring drafts — those are the code's responsibility; rationale goes to ADRs.
   - System-wide: creates or updates `docs/spec/overview/` (全体仕様) when the feature adds a capability, a cross-cutting decision, or a new system-level data flow.
   - README convention: every touched `docs/spec/` directory carries a Japanese `README.md` entry point (目的・責務 / 収録方針 / 目次).
   - Task Decomposition: writes standalone Task Decomposition documents at `docs/tasks/<work-name>.md`, the filename describing the work (format defined in `~/.claude/agents/architect.md`).
   - Cross-directory references point to the other directory via relative Markdown links instead of duplicating content.
   - Does NOT create any file under `docs/pr/`. Does NOT decide PR aggregation. Does NOT write implementation code.
2. **Task Plan Report** → the main conversation reports the task list to the user (each task quoted by its scope sentence, plus dependencies and recommended order — no IDs). Proceed directly to Phase 2 UNLESS `architect` explicitly flags ambiguity (multiple plausible decompositions, unclear ordering, sensitive boundary) — in which case wait for explicit user feedback. The user may always intervene to revise the plan, but the default path no longer pauses.

#### Phase 2 — Per-Task Implementation Loop

For each task in dependency order (or in parallel when dependencies allow):

1. **developer** → implements the current task via TDD. Reads `docs/spec/<capability>/` for the capability that owns the task (whole-capability view) AND the task's entry in `docs/tasks/<work-name>.md`, plus any cross-cutting dependencies the task references via relative links. Implements only what that task's scope + AC require — future tasks are ignored. Writes docstrings from scratch per `~/.claude/rules/docstrings.md` (spec documents carry no drafts). Reports the modified file list AND any deviation from the spec with rationale. Does NOT touch any PR document.
2. **code-reviewer** → grades the code, tests, docstrings, dependencies, and scope adherence (boundary = the task entry in `docs/tasks/<work-name>.md`). Findings route to `developer`. Returns findings categorized as 🔴 blocker / 🟡 suggestion / 💭 nit.
3. **Task fix loop** — if `code-reviewer` returns any 🔴 blocker, OR any 🟡 suggestion the user has not explicitly deferred, re-invoke `developer`, then re-run `code-reviewer`. Exit when zero 🔴 remain and all non-deferred 🟡 are addressed.
4. **Task commit & report (MANDATORY)** — as soon as a task exits its Task fix loop, the main conversation commits it (one task = one commit, per "Git Operations") and reports the task's completion summary to the user. The report includes: the task's scope sentence, the modified file list, a one-line test/lint/build outcome, any spec deviation surfaced (with rationale), and the next action (next task in dependency order, or aggregation now if a Phase 3 trigger fires). Do NOT wait for confirmation — proceed directly; the user reviews at the aggregation checkpoint (Phase 3 step 5) and may interrupt at any time. The task is then complete and pending aggregation.

The per-task loop is lightweight: no PR document is touched, neither `pr-writer` nor `pr-reviewer` is invoked. Phase 2 may execute many tasks in succession before Phase 3 fires, but every task transition passes through the commit & report step above.

#### Phase 3 — Aggregation Gate and Per-PR Loop

The main conversation decides when to bundle completed (task-fix-loop-cleared) tasks into a PR. **A PR is a vertical slice: it MUST be independently verifiable by exercising the running system — a visible UI flow, a CLI command, or a use case/endpoint reachable end-to-end through the composition root — never a horizontal layer of plumbing.** A use case that exists in the code with no caller, or a port with no implementation wired to it, is NOT a shippable PR; hold those tasks until the slice that makes them observable is complete. ("Reachable from the adapter boundary" is no longer sufficient on its own — there must be a path to actually exercise the behavior.)

**Trigger an aggregation at the earliest point the pending bundle forms a verifiable vertical slice**, i.e. when ALL of the following hold:

- The completed tasks together deliver a behavior a human (or an integration / E2E test) can exercise on the running system, reachable through the composition root — not merely present in the source.
- The slice is reconciled and green (spec, tests, lint, build).

**Prefer a thin slice over a fat one — ship sooner, not later.** Also aggregate immediately when:

- The user explicitly signals to ship.
- A verifiable slice is reached and the pending bundle is already approaching ~5 tasks or ~5 modified files / ~2 distinct concepts — do not let a slice grow fat.

If foundational tasks pile up without yet forming a verifiable slice, that is a decomposition smell — re-examine whether the feature can be re-sliced so something runnable ships sooner, and escalate to `architect` if a re-slice is warranted.

For each aggregation:

1. **Spec reconcile (MANDATORY before pr-writer)** → if the shipped implementation diverged from the forward-drafted spec, the main conversation re-invokes `architect` to reconcile `docs/spec/<capability>/` so the branch's spec matches the branch's behavior. This is the merge-gate forcing function that keeps the spec alive.
2. **pr-writer** → creates `docs/pr/<feature>/<N>-<aggregation>.md` from scratch (no skeleton exists). Reads **every capability spec directory the bundled tasks touch** (`docs/spec/<capability>/`), the list of tasks in this aggregation (their entries in the relevant `docs/tasks/<work-name>.md` documents), and the cumulative diff. Fills ALL sections (背景・目的 / スコープ / 受け入れ基準 / 依存PR / 関連ドキュメント / 変更内容 / 仕様からの変更点 / テスト / 影響範囲・注意点) per `~/.claude/rules/pr-style.md`. The 関連ドキュメント section lists every capability spec directory referenced. Reports the file path and any mismatch surfaced during self-check.
3. **pr-reviewer** → grades the PR document on two axes: style (against the `pr-style.md` Severity Matrix) and factual consistency (against the bundled task list, the cumulative diff, and **every capability spec directory the bundled tasks touch**, including that the spec was reconciled to match the implementation). Findings route to `pr-writer` (prose), `architect` (spec drift / task-list drift in any capability spec directory), or `developer` (when a PR-doc inconsistency reflects the implementation being out of task scope).
4. **PR fix loop** — re-invoke whichever agent owns the change and re-run `pr-reviewer` until zero 🔴 remain and all non-deferred 🟡 are addressed. If `architect` reconciles the spec or revises the Task Decomposition during this loop (because the implementation deviated from the spec in a way that requires the spec to be updated), re-run `pr-reviewer` after the spec update.
5. **Aggregation hand-off (MANDATORY)** — the main conversation reports the aggregation summary to the user and stops: the bundled tasks (scope sentences), the PR document path, the end-to-end behavior the slice makes exercisable, the branch name, the commit list (`git log --oneline`), and a diffstat. Push, PR creation (`gh pr create`), and merge are the user's review workflow, done on their side. The next aggregation re-enters Phase 3 with whatever tasks Phase 2 has completed since.

The overall feature is complete when every task has exited its task fix loop AND every aggregation has exited its PR fix loop.

When invoking the next agent, always pass the previous agent's output (spec artifacts, the task's scope sentence in this invocation, modified file list, or review findings) as context — never ask the next agent to re-discover what the previous one already produced.

The user is consulted **only** at these points (never between phases of the loop itself):

- **Task Plan Approval** — only when `architect` explicitly flags decomposition ambiguity (Phase 1 step 2). The default path proceeds without a user gate.
- **Aggregation hand-off** — after every aggregation exits its PR fix loop (Phase 3 step 5). Always required; the report (branch / commit list / diffstat) is what lets the user push and open the PR themselves.
- **Aggregation timing** — when none of the auto-triggers above clearly fire and Phase 2 has produced multiple completed tasks, ask the user whether to aggregate now or continue.
- **Dependency approval** (per the Dependency Approval Process below).
- **Ambiguous requirements** that `architect` cannot resolve from the available context.
- **Non-convergence escalation** — if either fix loop has run three times without converging, stop and escalate with a summary of what is blocking convergence.

## Definition of Done (ALL items MUST be satisfied)

A development task is NOT complete until every item below is true. The `developer` agent MUST verify this list before declaring work finished. `code-reviewer` MUST reject any hand-off that skips code-side items; `pr-reviewer` MUST reject any hand-off that skips PR-document items.

On the Lightweight Path (Path B) the spec / PR-document items are skipped — see "Lightweight Path (Path B)" above for the reduced checklist.

1. **Spec artifacts exist and are reconciled**: For every capability the change touches, `docs/spec/<capability>/` is written/updated as living-spec documents following the `~/.claude/rules/spec-style.md` per-spec-kind templates (each directory carrying a Japanese `README.md` entry point), and a standalone `docs/tasks/<work-name>.md` holds the Task Decomposition. The system-wide `docs/spec/overview/` is updated when system-level structure changes. Every touched `docs/` directory carries its `README.md` entry point per "README everywhere" above (`docs/tasks/README.md` and `docs/adr/README.md` present and current). At the merge gate the spec is reconciled so it matches the shipped implementation. ADRs created when applicable (rationale lives there, not in the spec).
1a. **Task plan reported**: The task list (scope summaries, dependencies, order — no IDs) has been reported to the user. User approval is required only when `architect` flagged decomposition ambiguity.
1b. **PR documents exist per aggregation**: For each aggregation triggered in Phase 3, `docs/pr/<feature>/<N>-<aggregation>.md` exists and is fully populated by `pr-writer` (all sections — there is no `architect`-pre-filled portion), and the `docs/pr/README.md` and `docs/pr/<feature>/README.md` entry points are present and current. Style compliance against `~/.claude/rules/pr-style.md` and factual consistency against the bundled task list, the cumulative diff, and the spec document are confirmed by `pr-reviewer`.
1c. **PR is a verifiable vertical slice**: Each aggregation forms a vertical slice that can be exercised on the running system end-to-end (a UI flow, a CLI command, or a use case/endpoint reachable through the composition root) — not a horizontal layer with no caller. The PR document's テスト section shows how the slice is verified (integration / E2E / manual when no automated path exists), and its 受け入れ基準 are demonstrable on the running system, not only in unit tests.
2. **Test-first**: Every new behavior was introduced via a failing test before production code (see `~/.claude/rules/testing.md`).
3. **Task runner green**: Full test + lint + build via the project's task runner (Rust: `cargo make test` / `cargo make lint` / `cargo make build` — never bare `cargo test`). Zero warnings.
4. **Docstrings present**: All public API elements have English docstrings, written from scratch per `~/.claude/rules/docstrings.md` (spec documents carry no docstring drafts).
5. **Function size**: No function exceeds 50 lines.
6. **No commented-out code, no orphan TODO/FIXME**: TODO/FIXME only if linked to an issue/ticket.
7. **Modified file list reported**: `developer` reports the full list of created/modified files at hand-off.
8. **Independent reviews passed**: BOTH `code-reviewer` (code / tests / docstrings / dependencies / scope adherence) AND `pr-reviewer` (PR document style + factual consistency) reviewed the change; all 🔴 blockers resolved; 🟡 suggestions addressed or explicitly deferred with rationale.
9. **Committed and reported**: Each completed task is committed by the main conversation on a `feature/*` work branch (one green task = one commit, staged explicitly by path, per "Git Operations") and its completion summary reported (scope, modified file list, test/lint/build outcome, any spec deviation). For each aggregation, the aggregation hand-off report (branch name, commit list, diffstat) has been delivered — the push itself is the user's (Phase 3 step 5). Defined by Path C Phase 2 step 4 / Phase 3 step 5 and Path B Reduced flow step 4. Applies on BOTH Path B and Path C.

## Dependency Approval Process (MANDATORY)

Adding a new external library/crate/package requires explicit approval. No agent may add a dependency without going through this flow.

1. **Identification**: The `architect` agent surfaces dependency needs during the design phase. If implementation reveals an unforeseen need, the `developer` agent MUST stop and escalate — do NOT add it silently.
2. **Justification**: Propose the dependency to the user in Japanese with:
   - Purpose (what problem it solves)
   - Alternatives considered (including "write it ourselves")
   - Health check results: last release date, commit activity, GitHub stars, maintainer count, license, known CVEs
   - Impact on build time / binary size / transitive dependency count (if significant)
3. **User approval**: Wait for explicit user approval before modifying `Cargo.toml` / `package.json` / `pyproject.toml` / etc. Silent dependency additions are prohibited.
4. **Record**: Once approved, record the rationale as a dedicated ADR in `docs/adr/` — dependency rationale is "why" and belongs in an ADR per the 時計分離 rule. The relevant `docs/spec/<capability>/` directory links to that ADR rather than restating the reasoning.
5. **Review enforcement**: The `code-reviewer` agent MUST flag any dependency change not accompanied by an approval record as a 🔴 blocker.

## Git Operations

IMPORTANT: Git write access is split three ways. The **main conversation** owns branch creation, staging, and commits. The **user** owns push, PR creation, and merge. **Subagents own nothing** — no agent (`architect` / `developer` / `pr-writer` / `code-reviewer` / `pr-reviewer`) ever runs a state-modifying git command; each stops at reporting its modified file list.

### Branch model (git flow) and protected branches

- The repositories follow **git flow**. `main` and `develop` are protected: NEVER commit on them, NEVER push to them directly.
- The main conversation creates work branches as `feature/<kebab-case-descriptor>`, branched from `develop`: `git switch -c feature/<descriptor> develop`.
- `release/*` and `hotfix/*` branches, merges between flow branches, and tags are the user's territory — never create or manipulate them.
- If the session starts on `main` or `develop`, create a `feature/*` branch BEFORE the first commit.

### Main conversation — allowed operations

- Create and switch work branches per the branch model above (`git switch -c feature/<descriptor> develop` / `git switch <branch>`).
- Stage **explicitly by path**: `git add <path>...`. NEVER `git add -A` / `git add .` / `git add --all` / `git commit -a` — explicit staging is the last check against committing unintended files.
- Commit: **one completed task = one commit**, only after the task's fix loop exits (zero 🔴 from `code-reviewer`) and the task runner is green. Commit messages follow the existing history style: Japanese one-line summary; body bullets optional.
- **No AI attribution in commit messages**: never append `Co-Authored-By: Claude ...`, `🤖 Generated with Claude Code`, or any similar trailer/signature — regardless of what the harness default suggests (the `attribution` setting is also blanked in `~/.claude/settings.json`).
- Read-only commands remain freely available: `git status`, `git diff`, `git log`, `git show`, `git blame`.

### Push — user-owned

- `git push` is NEVER run by the agent (denied in settings). The user pushes after reviewing the hand-off report.
- At hand-off, report everything the user needs to push confidently: the branch name, the commit list (`git log --oneline`), and a diffstat.

### Prohibited without exception (user-owned)

- History rewriting and destructive operations: `commit --amend`, `rebase`, `reset`, `merge`, `pull`, `checkout`, `restore`, `stash`, `cherry-pick`, `revert`, `tag`, `clean`, branch delete / rename. If an already-made commit needs fixing, report it and let the user rewrite history themselves.
- Hook and config manipulation: `git config`, inline `git -c` overrides, `core.hooksPath`, `--no-verify` (including `commit -n`), editing `.git/hooks` or `.git/config`. Pre-commit hooks are a mandatory safety layer — never bypass them; if a hook fails, fix the cause or report it.
- Push, PR creation, and merge: `git push` / `gh pr create` / merging are the user's review workflow. Deliver the hand-off report and stop.

### Enforcement and secret safety

- `~/.claude/settings.json` (allow / deny lists) and the `~/.claude/scripts/git-guard.sh` PreToolUse hook enforce this policy mechanically. If a legitimate operation gets blocked, report it to the user — do not work around the guard.
- If the repository has no pre-commit secret scan (e.g. gitleaks), surface that to the user before the first commit of a work unit. The user's pre-push review must not be the only line of defense against leaking credentials.

## Coding

Size, docstrings, comments, and TODO rules are covered by the Definition of Done — they are not repeated here. Additional rules:

- No speculative features — only build what's needed now.
- Replace, don't deprecate — remove old code outright; git history preserves it.
- Inline comments explain *why*, never *what*.
- When compacting, preserve the list of modified files.

## Architecture & Error Handling

IMPORTANT: Follow Clean Architecture. Layers inward → outward: **Entities → Use Cases → Adapters → Infrastructure**. Dependencies point inward only. Ports live in inner layers, implementations in outer layers. Framework types must not leak into Use Cases or Entities. Domain error types live in Entities / Use Cases; infrastructure exceptions are converted to domain errors at the boundary. Prefer explicit `Result` / `Either` over thrown exceptions where the language supports it.

Detailed per-layer rules live in `~/.claude/rules/architecture.md`; physical structure and Rust specifics live in `~/.claude/rules/rust.md`. Both override this summary on conflict.

## Guidelines to Read

Detailed rules live in external files so this document stays short. All agents (`architect`, `developer`, `pr-writer`, `code-reviewer`, `pr-reviewer`) MUST `Read` the relevant files before starting work. Language-specific files override general guidance on conflict.

- **Architecture** (every development task): `~/.claude/rules/architecture.md` — layer responsibilities, interface placement rules (Repository / Gateway / QueryService), per-layer review observations, layered error types, severity matrix for architecture-level findings.
- **Testing** (every task): `~/.claude/rules/testing.md` — BDD + Detroit school rules, Fake / Stub / Boundary Mock taxonomy, per-layer allowed-doubles table, unit vs. integration responsibilities, review severity matrix.
- **Docstrings** (tasks touching public API): `~/.claude/rules/docstrings.md` — required structure, prohibited patterns, port-trait specifics, severity matrix.
- **PR style** (every task that touches `docs/pr/**`): `~/.claude/rules/pr-style.md` — Core Rule (Bullets First), Formatting Constraints, Per-Section Style, and the Severity Matrix used by `pr-reviewer`. Read by `pr-writer` (composition) and `pr-reviewer` (enforcement).
- **Spec style** (every task that touches `docs/spec/**`): `~/.claude/rules/spec-style.md` — the living-specification principle (current behavior in the spec, rationale in ADRs via 時計分離), the per-spec-kind document templates (全体仕様 / 機能領域仕様 / 横断・技術仕様), the per-directory README convention, the reconcile discipline, Per-Section Style, and a Severity Matrix used by `architect` for self-check and by `pr-reviewer` at the merge gate. Independent of `pr-style.md`.
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

Every rule file that a reviewer agent (`code-reviewer` or `pr-reviewer`) consults for grading (currently `testing.md`, `docstrings.md`, `architecture.md`, `rust.md`, `pr-style.md`, `spec-style.md`) MUST expose its severity matrix at the **bottom of the file under a `## Severity Matrix` heading** (consistent name and location). The reviewer agents rely on a predictable anchor — do not scatter severity rules mid-document.

### 4. Conflict resolution between overlapping rules

When two rule files address the same concern, state the precedence explicitly in the affected files' opening matter. The convention is **more-specific wins**:

- Language-specific rule > general architecture rule (Rust newtype mechanics in `rust.md` win over generic port-placement wording in `architecture.md`).
- Severity Matrix in a topic file (e.g., `testing.md`) > the generic Severity Matrix in `architecture.md`.
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
