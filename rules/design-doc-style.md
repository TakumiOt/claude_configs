---
name: design-doc-style
description: Authoritative style rules for every file under docs/design/<bounded-context>/. Owned by architect; self-graded against the Severity Matrix at the bottom. Independent of pr-style.md; conflicts resolved per Precedence.
---

# Design Document Style Rules

Single source of truth for the visual and structural style of `docs/design/<bounded-context>/` directories. `architect` writes the documents and self-checks against the Severity Matrix at the bottom before declaring the design phase done. A future design-reviewer agent grades against the same matrix.

## Precedence

This file wins over style sections in `~/.claude/agents/architect.md`. It loses to `~/.claude/rules/architecture.md` (technical principles like layer responsibilities and port placement) — those are domain-of-truth rules, while this file governs document presentation.

This file is **independent of** `~/.claude/rules/pr-style.md`. The two address different audiences and lifecycles; rules are not transitively inherited. Where a rule appears identical across both files, it is restated here for clarity.

## Scope

Applies to every Markdown file inside `docs/design/<bounded-context>/` directories. Per `~/.claude/CLAUDE.md` "Documentation directory layout", design docs are organized **by bounded context** (one directory per bounded context, including cross-cutting layers like `shared-kernel` and `infrastructure`). The design directory is wholly architect-owned and is created/updated in Phase 1 of the Orchestration Loop. Updates during Phase 2 / Phase 3 (when implementation reveals design drift) are also bound by this file.

Internal file splitting inside a bounded-context directory is at the architect's discretion. Small bounded contexts may keep everything in `README.md`; larger ones split per topic. Required Sections (below) are satisfied **at the directory level** — every required section must be present somewhere in the directory, but architect chooses which file hosts it. Cross-bounded-context references use relative Markdown links (e.g. `../shared-kernel/README.md`) instead of duplicating content.

Each bounded-context directory MUST contain a `README.md` that serves as the entry point — background, scope summary, dependency edges to other bounded-context directories, and a table of contents pointing to internal files.

ADR files (`docs/adr/<NNNN>-<title>.md`) are NOT covered here; ADRs follow their own short template (Status / Context / Decision / Consequences) per `~/.claude/agents/architect.md`.

## Language

- Document body: Japanese.
- Code identifiers, file paths, type names, port signatures, code snippets: native form (English / project-native), kept in backticks or fenced code blocks.
- No JP/EN code-mixing, no forced kanji translations of industry-standard katakana, no coined kanji compounds, no direct-translation calques. Full rule and substitutions in `~/.claude/CLAUDE.md` "Language & Documentation Policy".
- This rule file: English (per `~/.claude/CLAUDE.md` Rules Directory Governance §6).

## Core Rule: Bullets First

**Bullets are the default and dominant format. Prose is the exception.**

Prose is permitted ONLY for:

1. A single short lead-in sentence framing a bullet list.
2. Trade-off analysis where a reasoned narrative is genuinely clearer than bullets (rare; usually still bulleted with sub-bullets).
3. Sequence diagram captions (one short sentence per diagram).

Prose is PROHIBITED for: enumeration of 2+ items, walking through reasons / consequences / edge cases in paragraph form, narrative transitions between bullet groups, closing a bullet list with a wrap-up paragraph.

## Formatting Constraints

- **One sentence per line, Markdown hard break**: end each sentence with `。` + two trailing spaces + newline. The last sentence before a blank line does not need trailing spaces.
- **Sentence length**: aim for ~120 characters. Guideline only — not flagged.
- **One bullet = one sentence**. If a bullet needs more context, split it into a parent + sub-bullets.
- **Bullets lead with role, not name**. The grammatical subject of every top-level bullet MUST be a role / behavior / decision in plain language — not a code identifier (file path, function, type, crate, module, env-var). Code identifiers go in parentheses after the role descriptor. Sub-bullets MAY use code identifiers as subjects when the parent bullet has already established the role.
- **Hoist enumerations of related identifiers into sub-bullets**. Trigger: parenthetical reaches 3+ identifiers, OR spans 2+ categories, OR makes the parent sentence hard to read in one pass.
- **Use `###` and `####` to structure long sections**. Top-level sections are `##`; subsections are `###`; further subdivision is `####`. Maximum heading depth: `####`.
- **Blank line between distinct ideas, not between bullets of the same list**.

## Required Sections (in order)

The bounded-context directory MUST include the following top-level (`##`) sections in this order, **across the directory's files as a whole**. The architect chooses which file hosts each section: small directories may keep everything in `README.md`; larger directories split per topic. The order constraint applies to the canonical reading sequence — when a reader follows the `README.md`'s table of contents, sections should appear in this order. **必須** sections are always required; **任意** sections are included only when the bounded context actually exercises them.

1. **背景・目的** (必須). Why this feature exists; the user-facing capability it delivers.
2. **要件整理** (必須). Clarified requirements per `~/.claude/agents/architect.md` "Requirements clarification". Sub-sections: 関係者 / 入出力 / エラー・境界条件 / 受け入れ基準 / データライフサイクル / 連携 / 依存追加候補.
3. **用語** (新規ドメイン用語が 3 つ以上現れる場合は必須). Glossary mapping each new domain term to a one-sentence definition.
4. **Bounded Context** (必須). Which domain crate hosts this bounded context, and which other bounded contexts it depends on. For cross-cutting layers (`shared-kernel`, `infrastructure`), describe the role they play and which bounded-context directories reference them. Cite the dependency graph rule consulted in `~/.claude/rules/architecture.md`.
5. **Use Case 一覧** (必須). Each use case as `### UC-<N>: <name>` with input / output / error variants.
6. **Port 一覧** (新規 port を導入する場合は必須). Each port with signature, placement layer (Entity / Use Case), and citation to the placement judgement table in `architecture.md`.
7. **エラー型階層** (必須). Per-layer error types (DomainError in Entities, UseCaseError in Use Cases) and the wrapping relationship.
8. **シーケンス図** (任意). Mermaid `sequenceDiagram` blocks for inter-layer flows that are not obvious from the text.
9. **トレードオフ** (必須). At least 2 options with their pros / cons / cost / risk; recommendation with rationale at the end.
10. **Docstring 草案** (新規 port を導入する場合は必須). Port-level docstring drafts in Japanese. Format defined verbatim in `~/.claude/agents/architect.md` "Port docstring drafts (Japanese, port-level only)" — this rule file does not duplicate it.
11. **タスク分解** (必須). Task list per `~/.claude/agents/architect.md` "Task Decomposition" — format defined there, not duplicated here.
12. **関連 ADR** (該当 ADR がある場合は必須). Bullets of relative Markdown links to ADRs that this design depends on or supersedes.

Sections may be reordered ONLY when the feature genuinely benefits (e.g., trade-off resolution drives the bounded-context choice). State the reordering reason in a one-line note at the top of the section.

## Per-Section Style

### 背景・目的

- 3 bullets or a 2–3 sentence paragraph maximum. Linking to PRD / spec is acceptable.

### 要件整理

- One `###` subsection per concern (`### 関係者`, `### 入出力`, `### エラー・境界条件`, etc.). Bullets within.
- Bounded-context-level acceptance criteria are listed in `### 受け入れ基準` here as a plain bullet list. **No AC IDs** — write the criterion itself as the bullet content. Tasks reference these criteria by quoting or paraphrasing the bullet text in their `受け入れ基準` cell, not by ID.
- 依存追加候補 lists external libraries / crates that the design might require. Each candidate is a parent bullet with rationale and health-check inputs in sub-bullets, per `~/.claude/CLAUDE.md` Dependency Approval Process.

### 用語

- Markdown table: `| 用語 | 定義 |`. One row per term, definition is one sentence.
- Drop the section entirely when fewer than 3 new domain terms appear.

### Bounded Context

- Bullets answering: which existing domain crate hosts the feature, OR what new crate is added (with rationale).
- Cite the relevant `architecture.md` section for the dependency-graph rule consulted.

### Use Case 一覧

- Each use case as `### <UseCaseName>` where `<UseCaseName>` is the natural function/struct name the implementation will use (e.g., `### IngestCountingEvents`). **No numeric ID prefix.** Body covers 入力 / 出力 / エラー variants as bullets or a small table.
- Cross-bounded-context orchestration: name the central bounded context that owns the use case, list Gateway ports the central bounded context calls into the other bounded context through.

### Port 一覧

- Each port as `### <PortName> (Repository | Gateway | QueryService)`. **No numeric ID prefix.** The `<PortName>` is the natural trait name used in code (e.g., `### CountingEventRepository (Repository)`).
- Body: signature in a fenced ` ```rust ` code block, placement layer + judgement-table citation as bullets, summary of what the port abstracts.
- Trait-method `# Errors` clauses MUST list domain-error variants only — no infrastructure errors (`sqlx::Error`, `reqwest::Error`, etc.) per `~/.claude/rules/docstrings.md` "Trait-level / Method-level".

### エラー型階層

- Show the wrapping graph as a bulleted tree or a compact code block.
- One sentence per error variant naming the domain meaning, not the infrastructure cause.

### シーケンス図

- Mermaid `sequenceDiagram` block. Caption above the block as one bullet describing the flow.
- One diagram per non-obvious flow; do not draw obvious linear flows.

### トレードオフ

- For each option: `#### 案 <N>: <name>`, then bullets of pros / cons / cost / risk.
- Final `#### 推奨` subsection with the chosen option and a one-sentence rationale.

### Docstring 草案

- Format defined verbatim in `~/.claude/agents/architect.md` "Port docstring drafts (Japanese, port-level only)". This file does not duplicate it. Drafts cover ports only; entity / use-case docstrings are written by `developer` from `~/.claude/rules/docstrings.md`.

### タスク分解

- Rendered as a **Markdown table** (`| スコープ | 受け入れ基準 | 依存タスク |`) with one row per task. **No ID column** — tasks are identified by their scope sentence. Multiple AC entries within a cell are separated by `<br>` and written as plain content (no `AC-N:` prefix).
- The 依存タスク cell references prerequisite tasks by **content**, not by ID. Same-directory dependencies cite the prerequisite task's scope or a short paraphrase (e.g., 「`Clock` ポート定義」). Cross-directory dependencies cite the directory and the task content (e.g., 「`shared-kernel` の `Clock` ポート定義タスク」). Use 「なし」 when the task has no dependency.
- Column definitions and worked example live in `~/.claude/agents/architect.md` "Task Decomposition" → "Required Section in the Design Document". This file does not duplicate them.
- Do NOT render tasks as `###` subsections with bullet bodies; the table is the required shape.

### 関連 ADR

- Bullets of relative Markdown links: `[ADR-<NNNN> (Status)](../adr/<NNNN>-<title>.md) — <one-sentence relevance>`.

## Severity Matrix

`architect` uses this matrix when self-checking before declaring the design phase done. A future design-reviewer agent (if introduced) grades against the same matrix. Style findings always route to `architect` (the document is wholly architect-owned).

| Observation | Severity |
|---|---|
| Required Section missing | 🔴 |
| Required Sections out of canonical order without an inline reordering note | 🟡 |
| Port introduced without placement layer annotation OR without citing the architecture.md judgement table | 🔴 |
| Port `# Errors` clause referencing infrastructure error types (`sqlx::Error`, `reqwest::Error`, etc.) | 🔴 |
| Use case missing input / output / error breakdown | 🔴 |
| トレードオフ presents fewer than 2 options OR omits the recommendation | 🔴 |
| Enumeration of 2+ items written as prose instead of a bulleted list | 🔴 |
| Multiple sentences on a single line without `  ` hard-break | 🔴 |
| 用語 list rendered as bullets instead of a Markdown table | 🟡 |
| タスク分解 rendered as `###` subsections / bullets instead of a Markdown table | 🟡 |
| タスク分解テーブルが ID 列(`T-N`)を含む、または受け入れ基準が `AC-N:` 等の ID プレフィックス付きで書かれている | 🔴 |
| Use Case 見出しが `### UC-<N>:` 等の ID プレフィックス付き(自然な関数名のみで参照すべき) | 🔴 |
| Port 見出しが `### P-<N>:` 等の ID プレフィックス付き(自然な trait 名のみで参照すべき) | 🔴 |
| トレードオフ presents options as one prose paragraph instead of `#### 案 <N>` subsections | 🟡 |
| Coined kanji compound (`依存集約点`, `組み立て中枢`) instead of a verb phrase or backticked English | 🟡 |
| Direct-translation calque (「〜することが可能」「〜が行われる」「〜の導入を実施した」) | 🟡 |
| Top-level bullet whose subject is a code identifier instead of a role / behavior | 🟡 |
| Parenthetical packing 3+ related identifiers (or 2+ categories) instead of sub-bullets | 🟡 |
| Section with 3+ thematic subgroups uses prose lead-ins instead of `###` sub-headings | 🟡 |
| English noun phrase in Japanese prose where natural Japanese exists (outside backticks) | 🟡 |
| Forced kanji translation of an industry-standard katakana term (`接続点` for `port`, etc.) | 🟡 |
| Bullet with 3+ sentences without being split | 🟡 |
| シーケンス図 lacks a one-sentence caption | 💭 |
| Lead-in sentence longer than one sentence | 💭 |
