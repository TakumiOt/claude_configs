---
name: pr-style
description: Authoritative style rules for every section of docs/pr/<feature>-<slice>.md. Owned jointly by architect (scope sections) and pr-writer (prose sections); enforced by pr-reviewer.
---

# PR Document Style Rules

This file is the single source of truth for the visual and structural style of `docs/pr/<feature>-<slice>.md`. Every agent that reads, writes, or reviews a PR document MUST follow the rules below.

## Precedence

On conflict with style-related wording elsewhere, this file wins:

- Wins over style sections in `~/.claude/agents/architect.md`, `~/.claude/agents/pr-writer.md`, and `~/.claude/agents/pr-reviewer.md`.
- Loses to agent-specific responsibilities (who fills which section, workflow ordering). Those live in the agent files and are out of scope here.

## Scope

Applies to every section, regardless of which agent authors it:

- **architect-owned sections**: 背景・目的, スコープ, 受け入れ基準, 依存スライス, Diff 予算, 関連ドキュメント.
- **pr-writer-owned sections**: 変更内容, 設計からの変更点, テスト, 影響範囲・注意点.

Section ownership (who fills what, when) is defined in the agent files; this rule governs *how* each section must read.

## Language

- Document body: Japanese.
- Code identifiers, file paths, type names, snippets: native form (English / project-native).
- This rule file itself: English.

## Core Rule: Bullets First

**Bullets are the default and dominant format for every section. Prose is the exception, not the rule.**

Prose is permitted ONLY for:

1. A single short lead-in sentence that frames a bullet list.
2. A section body whose total content is one short sentence (splitting into a single bullet would be silly).
3. The single canonical "no deviation" line of `設計からの変更点` (`設計書のとおり実装。変更なし。`).

Prose is PROHIBITED for:

- Enumerating two or more items. Two items joined by "、" / "および" / "/" in one sentence is a bulleted list written wrong.
- Walking through reasons, consequences, or edge cases in paragraph form. Each reason / consequence / edge case is its own bullet.
- Narrative transitions between bullet groups. If two bullet groups belong together, nest them; if not, separate with a blank line.
- Closing a bullet list with a prose paragraph. The bullets are the content; no wrap-up is needed.

If a section currently reads as multiple consecutive paragraphs, convert each paragraph's core assertion into a bullet and delete the narrative glue.

## Formatting Constraints

- **One sentence per line with Markdown hard break**. End each sentence (whether inside a bullet or in a prose lead-in) with `。` followed by **two trailing spaces** and a newline. The two trailing spaces are the Markdown hard-break syntax — without them, consecutive lines render as a single paragraph. The last sentence before a blank line does NOT need trailing spaces.
- **Sentence length ≤ 80 characters**. Count includes Japanese characters, punctuation, spaces, and backticked identifiers. If a sentence exceeds 80 characters, split it or convert it to a bulleted list.
- **One bullet = one sentence**. If a bullet needs more context, split it into a parent bullet + sub-bullets — never pack multiple sentences into one bullet.
- **Sub-bullets at most 2 levels deep**. Deeper nesting means the content belongs elsewhere or needs its own section.
- **Blank line between distinct ideas, not between bullets of the same list**.

## Per-Section Style

### 背景・目的 (architect)

- Short. At most 3 bullets or one 2–3 sentence paragraph.
- Do NOT duplicate the design document. Link to it instead.

### スコープ (architect)

- Bulleted list of behaviors this slice delivers.
- Each bullet describes an observable behavior or a structural change reachable from the adapter boundary.
- File names may appear inside a bullet when they anchor the change; the bullet's subject is the change, not the file.

### 受け入れ基準 (architect)

- Bulleted list, each bullet starting with `AC-N: `.
- One acceptance criterion per bullet. Measurable and verifiable.

### 依存スライス (architect)

- Bulleted list of prerequisite slices, or the single line `なし` if none.
- Conditions that are not prerequisite slices (e.g., "Tailwind 依存追加のユーザー承認") go on their own bullet prefixed `前提条件: `.

### Diff 予算 (architect)

- One line stating the budget.
- If the slice is expected to exceed the budget, follow with a bulleted list of reasons. Never embed the reasoning in a paragraph.

### 関連ドキュメント (architect)

- Bulleted list of relative Markdown links.
- Never absolute paths.

### 変更内容 (pr-writer)

- Feature-level summary as bullets, grouped by conceptual piece of the change.
- Each group may have an optional one-sentence lead-in, followed by bullets.
- Do NOT write one bullet per modified file — group by concept. File names appear inside bullets when they anchor a change.
- Do NOT close the section with a prose paragraph.

### 設計からの変更点 (pr-writer)

- If the implementation followed the design, the entire section is the single line `設計書のとおり実装。変更なし。`
- If it deviated, each deviation is a parent bullet naming the deviation. Sub-bullets cover:
  - the reason the deviation was necessary, and
  - the effect on subsequent slices / acceptance criteria (if any).
- Do NOT write deviations as prose paragraphs.

### テスト (pr-writer)

- Behavioral themes as parent bullets; scenarios / edge cases as sub-bullets.
- Never list test function names paired with AC IDs. The section describes coverage intent, not the test runner's output.
- If AC traceability is useful, reference it as one compact trailing line (e.g., `（対応する Acceptance Criteria: AC-M2 〜 AC-M10）`).
- If no tests were added, state the reason in a single sentence, then list the verification substitutes (lint, build, manual check) as bullets.

### 影響範囲・注意点 (pr-writer)

- Bulleted list of reader-actionable items: breaking changes, required config updates, data migrations, deployment ordering, operational cautions.
- Each concern is a parent bullet; rationale / details go in sub-bullets when needed.
- Do NOT write concerns as prose paragraphs.
- Skip trivia the reader infers from the change itself.

## Anti-Patterns

- Multiple sentences packed on one line separated only by `。` (breaks per-sentence diff readability).
- Narrative paragraphs where bullets would do.
- A bullet containing three or more sentences (split it or add sub-bullets).
- Enumeration expressed as one sentence joined by `、` / `および` / `/`.
- File-by-file enumeration in 変更内容.
- Test function names as the primary content of テスト.
- Padding 設計からの変更点 with narrative when there is no deviation.
- Closing prose paragraph after a bullet list ("上記により〜〜となる。" etc.).

## Severity Matrix

`pr-reviewer` uses this matrix when grading PR document style and factual consistency. Findings are routed to `pr-writer` (pr-writer-owned sections), `architect` (architect-owned sections), or `developer` (when the implementation itself is out of scope) per the hand-off rules in `~/.claude/agents/pr-reviewer.md`.

| Observation | Severity |
|-------------|----------|
| Enumeration of two or more items written as prose instead of a bulleted list | 🔴 blocker |
| Prose paragraph where a bulleted list is required by Per-Section Style | 🔴 blocker |
| Multiple sentences on a single line without the `  ` hard-break | 🔴 blocker |
| File-by-file enumeration in 変更内容 | 🔴 blocker |
| Test function names as the primary content of テスト | 🔴 blocker |
| `設計からの変更点` padded with narrative when there is no actual deviation | 🔴 blocker |
| Closing prose paragraph appended after a bullet list | 🟡 suggestion |
| Sentence exceeds 80 characters | 🟡 suggestion |
| Bullet containing three or more sentences without being split | 🟡 suggestion |
| Sub-bullets nested deeper than 2 levels | 🟡 suggestion |
| Lead-in sentence longer than one sentence | 💭 nit |
| Minor wording inconsistencies between parallel bullets | 💭 nit |
