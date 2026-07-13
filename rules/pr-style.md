---
name: pr-style
description: Authoritative style rules for every section of docs/pr/<feature>/<N>-<aggregation>.md. Wholly pr-writer-owned (architect does not pre-fill anything); enforced by pr-reviewer.
---

# PR Document Style Rules

Single source of truth for the style of `docs/pr/<feature>/<N>-<aggregation>.md`. `pr-writer` writes the document; `pr-reviewer` enforces these rules via the Severity Matrix at the bottom.

## Precedence

This file wins over style sections in `~/.claude/agents/pr-writer.md` and `~/.claude/agents/pr-reviewer.md`. It loses to agent-specific responsibilities (who reads what, workflow ordering) — those live in the agent files.

## Scope

Applies to all sections: 背景・目的, スコープ, 受け入れ基準, 依存PR, 関連ドキュメント, 変更内容, 仕様からの変更点, テスト, 影響範囲・注意点. The PR document is wholly pr-writer-owned and is created from scratch at aggregation time per `~/.claude/CLAUDE.md` Phase 3.

## ディレクトリ README

`docs/pr/` 配下のディレクトリは `README.md` を入口として持つ (`~/.claude/CLAUDE.md` 「README everywhere」)。いずれも日本語で、`pr-writer` が PR ファイル作成時に作成・更新する。

- `docs/pr/README.md` — 目的・責務 (PR 文書を feature 単位で置く)、収録方針 (feature ごとにサブディレクトリ、ファイル名は `N-<aggregation>.md`、aggregation 時に `pr-writer` が作成)、目次 (各 feature への相対リンク)。
- `docs/pr/<feature>/README.md` — その feature が届けるものを 1 行で示し、収録する PR を連番順に各 1 行で列挙する (`N-<aggregation>.md` へのリンクと主旨)。依存順があれば明示する。
- README はナビゲーションであり、PR 本文のセクションをここに書かない。

## Language

- Document body: Japanese. Code identifiers, file paths, type names, snippets: native form in backticks.
- No JP/EN code-mixing, no forced kanji translations of industry-standard katakana, no coined kanji compounds, no direct-translation calques. Full rule and substitutions in `~/.claude/CLAUDE.md` "Language & Documentation Policy".
- **Do not use the bare word 「契約」/`contract`.** It names neither the *kind* of guarantee (error conditions / invariants / pre- & post-conditions / ordering / wire format / trait bounds) nor the *subject* (which port / function / type), so on its own a reader cannot tell what is promised. Qualify both (e.g. 「`SystemInfoProvider` が OS リソース観測を抽象する Gateway である旨」, 「`# Errors` が示すエラー条件」) or state the guarantee concretely (e.g. 「無効な PUT が現行値を破壊しない」). Acceptable only in conceptual/meta prose discussing the notion of contracts itself.
- This rule file: English (per `~/.claude/CLAUDE.md` Rules Directory Governance §6).

## Core Rule: Bullets First

**Bullets are the default and dominant format. Prose is the exception.**

Prose is permitted ONLY for:

1. A single short lead-in sentence framing a bullet list.
2. A section body whose total content is one short sentence.
3. The single canonical "no deviation" line of `仕様からの変更点`.

Prose is PROHIBITED for: enumeration of 2+ items, walking through reasons / consequences / edge cases in paragraph form, narrative transitions between bullet groups, closing a bullet list with a wrap-up paragraph.

## Formatting Constraints

- **One sentence per line, Markdown hard break**: end each sentence with `。` + two trailing spaces + newline. The last sentence before a blank line does not need trailing spaces.
- **Sentence length**: aim for ~120 characters. Guideline only — not flagged by `pr-reviewer`.
- **One bullet = one sentence**. If a bullet needs more context, split it into a parent + sub-bullets — never pack multiple sentences into one bullet.
- **Bullets lead with role, not name**. The grammatical subject of every top-level bullet MUST be a role / behavior / change in plain language — not a code identifier (file path, function, type, crate, module, env-var). Code identifiers go in parentheses after the role descriptor. Sub-bullets MAY use code identifiers as subjects when the parent bullet has already established the role.
  - Bad: `crates/legacy/` を新設し、〜〜を移設した。
  - Good: 既存コードを丸ごと隔離する過渡的な置き場を新設した (`crates/legacy/`)。
- **Hoist enumerations of related identifiers into sub-bullets**. Trigger: parenthetical reaches 3+ identifiers, OR spans 2+ categories, OR makes the parent sentence hard to read in one pass. List each category as its own sub-bullet under a role-led parent.
- **Use `###` sub-headings for sections with 3+ thematic groups**. Lead-in sentences are acceptable for 1–2 groups. Maximum heading depth: `####` (h4); deeper signals the section should split.
- **Blank line between distinct ideas, not between bullets of the same list**.

Worked examples for "lead with role" and "group by concept" live in `~/.claude/agents/pr-writer.md` "Concrete Examples".

## Per-Section Style

Every section follows the Formatting Constraints above. Section-specific rules below.

### 背景・目的

- Short. At most 3 bullets or one 2–3 sentence paragraph.
- Do NOT duplicate the spec document. Link to it.

### スコープ

- Bullets describing observable behaviors / structural changes the PR ships.
- **The PR is a vertical slice**: at least one bullet states the end-to-end behavior the slice makes exercisable on the running system (a UI flow, a CLI command, or a use case/endpoint reachable through the composition root). A PR whose スコープ is purely internal plumbing with no exercisable end is a decomposition problem — surface it to the orchestrator rather than documenting it as shippable.
- Composed from the union of the bundled tasks' スコープ entries — do not invent items, do not silently absorb implementation drift.

### 受け入れ基準

- Grouped by task using `###` sub-headings. Each `###` heading is the bundled task's scope sentence (or a short paraphrase that preserves intent). Under each heading, list that task's acceptance criteria as plain bullets. **No AC ID prefixes** (no `AC-N:` / `AC-<tag>-<n>:` etc.).
- Each bullet is one measurable, verifiable criterion sourced verbatim from the bundled task's 受け入れ基準 cell in the タスク分解 table (`docs/tasks/<work-name>.md`). Do not invent criteria, do not silently absorb implementation drift.
- When the aggregation bundles only 1–2 tasks, `###` sub-headings are still required so the structure stays consistent across PRs.

### 依存PR

- Bullets of relative paths to prerequisite PR files, or `なし`. Inferred from the bundled tasks' 依存タスク entries (which themselves cite prerequisites by content, not ID).
- Non-PR conditions go on their own bullet prefixed `前提条件: ` (e.g., dependency-approval requirements, environment-variable settings).

### 関連ドキュメント

- Bullets of relative Markdown links. Always include the spec document (the touched `docs/spec/<capability>/` directories); add ADRs the bundled tasks reference. Never absolute paths.

### 変更内容

- Feature-level summary, grouped by conceptual piece. Use `###` per group when 3+ groups exist.
- Apply "lead with role" and "hoist enumerations". Bullets reading like `<file path> を <verb>` are the most common smell — rewrite to lead with role.
- Do NOT enumerate one bullet per modified file. Do NOT close with a prose paragraph.

### 仕様からの変更点

- If the implementation followed the spec exactly, the entire section is the single line `仕様書のとおり実装。変更なし。`
- If it deviated, each deviation is a parent bullet naming the deviation. Sub-bullets cover the reason and the downstream effect on subsequent tasks / PRs.
- When 3+ deviations exist, promote each to `###`.

### テスト

- **The slice's verification path is visible**: because a PR is a verifiable vertical slice, this section MUST show how the end-to-end behavior is exercised — an integration / E2E row, or a manual-verification bullet when no automated path exists yet — not only unit-level coverage of the individual layers.
- **Default format: a Markdown table** with columns **層 (or 種別) | テーマ | 主なケース**.
  - 層 / 種別: entity unit / infrastructure / integration / contract / E2E / manual など、テスト基盤ごとの粒度。
  - テーマ: 行の振る舞い主題 (例: 「認証ユースケース」, 「永続化ラウンドトリップ」)。
  - 主なケース: シナリオ・境界条件をセル内で `/` 区切りで列挙。
- Additional columns (場所) only when the value varies meaningfully across rows.
- Bullets are acceptable when the section has only 1–2 themes. No tests added → state the reason in one sentence, then list verification substitutes (lint / build / manual) as bullets.
- When tests group into clearly distinct categories that don't fit one table, use `###` per category, each with its own table or bullet block.
- Never list test function names — describes coverage intent, not test runner output.
- AC traceability is implicit: テスト テーマ should align with 受け入れ基準 task groupings so a reader can pair them by content. Do NOT reintroduce AC IDs to make the linkage explicit.

### 影響範囲・注意点

- Bullets of reader-actionable items: breaking changes, config updates, data migrations, deployment ordering, operational cautions.
- Each concern is a parent bullet; rationale / details go in sub-bullets.
- When concerns span 3+ categories, promote each to `###`.
- Do NOT write concerns as prose paragraphs. Skip trivia the reader infers from the change itself.

## Severity Matrix

`pr-reviewer` uses this matrix when grading. Style findings always route to `pr-writer` (the document is wholly pr-writer-owned). Factual-consistency findings route to `pr-writer` (prose mismatch), `architect` (spec drift requiring Task Decomposition revision), or `developer` (implementation outside the bundled tasks' scope), per hand-off rules in `~/.claude/agents/pr-reviewer.md`.

| Observation | Severity |
|---|---|
| Enumeration of 2+ items written as prose instead of a bulleted list | 🔴 |
| Prose paragraph where Per-Section Style requires bullets | 🔴 |
| Multiple sentences on a single line without `  ` hard-break | 🔴 |
| File-by-file enumeration in 変更内容 | 🔴 |
| Test function names as the primary content of テスト | 🔴 |
| `仕様からの変更点` padded with narrative when there is no actual deviation | 🔴 |
| `テスト` with 3+ themes uses bullets instead of a Markdown table | 🟡 |
| Section with 3+ thematic groups uses prose lead-ins instead of `###` sub-headings | 🟡 |
| Heading depth deeper than `####` (h4) | 🟡 |
| Top-level bullet whose subject is a code identifier instead of a role / behavior | 🟡 |
| Parenthetical packing 3+ related identifiers (or 2+ categories) instead of sub-bullets | 🟡 |
| English noun phrase in Japanese prose where natural Japanese exists (outside backticks) | 🟡 |
| Forced kanji translation of an industry-standard katakana term (`接続点` for `port`, etc.) | 🟡 |
| Coined kanji compound (`依存集約点`, `組み立て中枢`) instead of a verb phrase or backticked English | 🟡 |
| Direct-translation calque (「〜することが可能」「〜が行われる」「〜の導入を実施した」) | 🟡 |
| Bare 「契約」/`contract` with neither the kind of guarantee nor the subject qualified (outside conceptual/meta prose) | 🟡 |
| Bullet with 3+ sentences without being split | 🟡 |
| Closing prose paragraph after a bullet list | 🟡 |
| 受け入れ基準 bullets prefixed with `AC-N:` / `AC-<tag>-<n>:` etc. (IDs were globally retired) | 🔴 |
| 受け入れ基準 lacks `###` task-scope groupings (flat bullet list) | 🔴 |
| `docs/pr/` or a `docs/pr/<feature>/` directory missing its `README.md` entry point, or the feature README not updated when this PR was added | 🔴 |
| スコープ describes only internal plumbing with no exercisable end-to-end behavior (the PR is not a verifiable vertical slice) | 🟡 |
| テスト shows only unit coverage with no end-to-end / integration / manual verification path for the slice | 🟡 |
| Lead-in sentence longer than one sentence | 💭 |
| Minor wording inconsistencies between parallel bullets | 💭 |
