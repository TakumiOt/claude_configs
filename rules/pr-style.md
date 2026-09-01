---
name: pr-style
description: Authoritative style rules for every section of the GitHub PR body (composed by pr-writer into a scratchpad file, published via --body-file). Wholly pr-writer-owned; enforced by pr-reviewer.
---

# PR Body Style Rules

Single source of truth for the style of the GitHub PR body. `pr-writer` composes the body (into a scratchpad file the orchestrator publishes via `--body-file`); `pr-reviewer` enforces these rules via the Severity Matrix at the bottom. No PR document file lives under `docs/` — the PR body itself is the deliverable (使い捨ての差分情報, per the 時計分離 rule).

## Precedence

This file wins over style sections in `~/.claude/agents/pr-writer.md` and `~/.claude/agents/pr-reviewer.md`. It loses to agent-specific responsibilities (who reads what, workflow ordering) — those live in the agent files.

## Scope

Applies to all sections: 背景・目的, スコープ, 受け入れ基準, 依存PR, 関連ドキュメント, 変更内容, 仕様からの変更点, テスト, 影響範囲・注意点. The PR body is wholly pr-writer-owned, composed in two stages per `~/.claude/CLAUDE.md` Phase 1 step 3 / Phase 3.

## PBI Issue Linkage

- The body's **last line** is `Closes #<issue>`, where `<issue>` is the shipped PBI's GitHub Issue number — merging the PR then closes the PBI automatically.
- Exactly one `Closes` line per PR (one PBI = one PR). A body with no `Closes` line, or with several, is a structural defect.
- The PBI issue is the source the 受け入れ基準 lead group quotes; cite it by its slice sentence in prose, by `#<issue>` only in the `Closes` line and the 依存PR section.

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

## Stage-1 Placeholder (draft PR period)

The PR body is authored in two stages (`~/.claude/CLAUDE.md` Phase 1 step 3 / Phase 3). Between them, the implementation-dependent sections are placeholders by design:

- During stage 1 (from draft PR opening until aggregation), each of 変更内容 / 仕様からの変更点 / テスト / 影響範囲・注意点 consists of exactly the canonical line `実装完了後に記載。` — nothing more.
- Free-form "planned" content in these sections (predicted diffs, expected test lists) is prohibited at stage 1 — it is fabrication ungrounded in any diff.
- The Severity Matrix below grades the **completed (stage-2) body**; `pr-reviewer` reviews only after stage 2. A placeholder line remaining at review time is 🔴.
- Design-grounded sections (背景・目的 / スコープ / 受け入れ基準 / 依存PR / 関連ドキュメント) and the `Closes #<issue>` line follow the full rules from stage 1 onward.

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

- The first `###` group is the shipped PBI itself: its heading is the PBI's slice sentence, and its bullets quote the PBI's slice-level 受け入れ基準 (the 動作確認 criteria) from the PBI issue body.
- Subsequent groups are per task, using `###` sub-headings. Each `###` heading is the bundled task's scope sentence (or a short paraphrase that preserves intent). Under each heading, list that task's acceptance criteria as plain bullets. **No AC ID prefixes** (no `AC-N:` / `AC-<tag>-<n>:` etc.).
- Each bullet is one measurable, verifiable criterion sourced verbatim from the PBI issue's slice-level 受け入れ基準 or the bundled task's 受け入れ基準 cell in its タスク分解 table. Do not invent criteria, do not silently absorb implementation drift.
- When the aggregation bundles only 1–2 tasks, `###` sub-headings are still required so the structure stays consistent across PRs.

### 依存PR

- Bullets of prerequisite PR references as `#<number>` (with the PR title or a one-line gist), or `なし`. Inferred from the bundled tasks' 依存タスク entries (which themselves cite prerequisites by content, not ID).
- Non-PR conditions go on their own bullet prefixed `前提条件: ` (e.g., dependency-approval requirements, environment-variable settings).

### 関連ドキュメント

- Bullets of repo-root-relative paths in backticks (e.g. `` `docs/spec/server/counting-ingestion/` ``) — GitHub PR bodies do not resolve relative Markdown links, so paths are cited as text. Always include the touched `docs/spec/<capability>/` directories; add ADRs the bundled tasks reference. Never absolute paths.

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
| 受け入れ基準 lacks the lead PBI group (slice sentence heading + slice-level AC) | 🟡 |
| `Closes #<issue>` line missing, duplicated, or citing the wrong PBI issue | 🔴 |
| Stage-1 placeholder line `実装完了後に記載。` remaining in any section at review time (stage 2 incomplete) | 🔴 |
| スコープ describes only internal plumbing with no exercisable end-to-end behavior (the PR is not a verifiable vertical slice) | 🟡 |
| テスト shows only unit coverage with no end-to-end / integration / manual verification path for the slice | 🟡 |
| Lead-in sentence longer than one sentence | 💭 |
| Minor wording inconsistencies between parallel bullets | 💭 |
