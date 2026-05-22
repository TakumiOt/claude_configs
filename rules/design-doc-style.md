---
name: design-doc-style
description: Authoritative structure and style rules for every file under docs/design/. Owned by architect; self-graded against the Severity Matrix at the bottom. Independent of pr-style.md; conflicts resolved per Precedence.
---

# Design Document Style Rules

Single source of truth for the structure and visual style of `docs/design/`. `architect` writes the documents and self-checks against the Severity Matrix at the bottom before declaring the design phase done. A future design-reviewer agent grades against the same matrix.

## Precedence

This file wins over style sections in `~/.claude/agents/architect.md`. It loses to `~/.claude/rules/architecture.md` (technical principles like layer responsibilities and port placement) — those are domain-of-truth rules, while this file governs document presentation.

This file is **independent of** `~/.claude/rules/pr-style.md`. The two address different audiences and lifecycles; rules are not transitively inherited.

## Scope

Applies to every Markdown file under `docs/design/`. Two kinds of documents:

- **基本設計書** (`docs/design/overview/`) — the system-wide design book. Why the system exists, who uses it, what it does, how the crates are structured. One per repository.
- **クレート設計書** (`docs/design/<crate>/`) — one directory per crate (a bounded context, or a cross-cutting crate such as `shared-kernel` / `infrastructure`).

`タスク分解` is **not** a design document. It lives in a standalone `docs/tasks/<work-name>.md` with its own format defined in `~/.claude/agents/architect.md`, and is not governed by this file.

ADR files (`docs/adr/<NNNN>-<title>.md`) follow their own short template and are not covered here.

## Core Principle: Basic Design, Not Detailed Design

Design documents are **基本設計** (high-level design). They convey purpose, responsibility, functionality, and structure — enough to understand *what each crate is for and what it does*. **詳細設計 (detailed design) lives in the code.**

The following MUST NOT appear in a design document — they are the code's responsibility:

- Full type signatures (`fn` signatures, struct field lists, trait method bodies).
- Error `enum` definitions (variant-by-variant code blocks).
- SQL / DDL / migration bodies.
- Docstring drafts.

Refer to these by name and role instead, and treat the code as the source of truth for the detail.

## Language

- Document body: Japanese.
- Code identifiers, file paths, type names, code snippets: native form (English / project-native), kept in backticks or fenced code blocks.
- No JP/EN code-mixing, no forced kanji translations of industry-standard katakana, no coined kanji compounds, no direct-translation calques. Full rule and substitutions in `~/.claude/CLAUDE.md` "Language & Documentation Policy".
- This rule file: English (per `~/.claude/CLAUDE.md` Rules Directory Governance §6).

## Core Rule: Bullets First

**Bullets are the default and dominant format. Prose is the exception.**

Prose is permitted ONLY for:

1. A single short lead-in sentence framing a bullet list.
2. Trade-off analysis where a reasoned narrative is genuinely clearer than bullets (rare; usually still bulleted).
3. Sequence diagram captions (one short sentence per diagram).

Prose is PROHIBITED for: enumeration of 2+ items, walking through reasons / consequences / edge cases in paragraph form, narrative transitions between bullet groups, closing a bullet list with a wrap-up paragraph.

## Formatting Constraints

- **One sentence per line, Markdown hard break**: end each sentence with `。` + two trailing spaces + newline. The last sentence before a blank line does not need trailing spaces.
- **Sentence length**: aim for ~120 characters. Guideline only — not flagged.
- **One bullet = one sentence**. If a bullet needs more context, split it into a parent + sub-bullets.
- **Bullets lead with role, not name**. The grammatical subject of every top-level bullet MUST be a role / behavior / decision in plain language — not a code identifier. Code identifiers go in parentheses after the role descriptor. Sub-bullets MAY use code identifiers as subjects once the parent has established the role.
- **Hoist enumerations of related identifiers into sub-bullets**. Trigger: parenthetical reaches 3+ identifiers, OR spans 2+ categories.
- **Use `###` and `####` to structure long sections**. Maximum heading depth: `####`.
- **Blank line between distinct ideas, not between bullets of the same list**.

## Document Structure

### 基本設計書 — `docs/design/overview/`

Across its files, the basic-design book MUST cover:

- システムの目的・責務 — why the system exists, the capability it delivers, what it does NOT do.
- 想定ユーザー — the actors and how they authenticate.
- ユーザーごとのユースケースと権限 — what each actor can do.
- 機能一覧 — the features the system provides.
- クレート構成と依存グラフ — the crate list and their dependency edges.
- データフロー図 — the major flows that cross crates.
- システム全体の設計判断 — cross-cutting decisions, with an ADR index.

Recommended file layout: `README.md` (目的・責務・想定ユーザー・機能一覧・目次) / `use-cases.md` / `architecture.md` (構成・依存グラフ・データフロー) / `design-decisions.md`. The `README.md` is the entry point and carries a 目次.

### クレート設計書 — `docs/design/<crate>/`

One directory per crate. The `README.md` is always the entry point — 目的・責務, スコープ (扱う / 扱わない), 連携, 目次. The architect picks one of three templates by crate kind.

**ドメインクレート** — `README.md` / `use-cases.md` / `domain-model.md` / `interfaces.md` / `design-notes.md`.

- `use-cases.md` — 提供するユースケース。各々の名前・目的・入出力の概要・主要なエラー方針。
- `domain-model.md` — 所有する集約・値オブジェクトの名前と役割、永続化データの概要、用語集。
- `interfaces.md` — 公開ポート (名前・種別・配置レイヤー・抽象対象)、HTTP API / CLI。
- `design-notes.md` — クレート固有の設計判断・トレードオフ・制約。
- A domain crate with no use cases of its own omits `use-cases.md`; the README states the reason.

**横断・技術クレート** (`infrastructure` 等) — `README.md` / `port-implementations.md` / `boundary-policy.md` / `platform.md` / `design-notes.md`.

- `port-implementations.md` — 実装する全ポートの一覧 (ドメイン別) と永続化基盤。
- `boundary-policy.md` — 境界変換 (フレームワーク例外 → ドメインエラー) と識別子変換のポリシー。
- `platform.md` — マイグレーション基盤・ロギング・デプロイ前提などの技術基盤。

**横断・kernel クレート** (`shared-kernel` 等) — `README.md` / `provided-items.md` / `design-notes.md`.

- `provided-items.md` — 提供する値オブジェクト・横断ポート・エラー。

Internal file splitting beyond the template is at the architect's discretion based on size; a small crate may merge files, but the `README.md` entry point with a 目次 is always required. Cross-directory references use relative Markdown links.

## Per-Section Style

### 目的・責務 / スコープ / 連携

- 3 bullets 程度を上限とする。基本設計書や ADR の内容を重複させず、リンクで参照する。
- 連携は依存先 / 依存元 / 外部 Actor を箇条書きまたは表で示す。

### ユースケース

- ユースケースごとに `##` 見出し。見出しは実装で使う自然な関数名(`### UC-<N>:` のような ID 接頭辞は禁止)。
- 入出力は概要のみ。DTO の全フィールドや型シグネチャは書かない。
- エラーは方針(どの条件で何を返すか・どの HTTP ステータスに対応するか)を書く。`enum` 定義は書かない。

### ドメインモデル

- 集約・エンティティ・値オブジェクトは「名前・役割・主要な不変条件」を表で示す。型定義の全文は書かない。
- 永続化されるデータはテーブル名と用途を示す。DDL は書かない。
- 用語は Markdown 表 (`| 用語 | 定義 |`) で示す。

### インターフェース / ポート

- ポートは「名前・種別 (Repository / Gateway / QueryService)・配置レイヤー・抽象する対象」を表で示す。メソッドシグネチャは書かない。
- 配置レイヤーの根拠として `~/.claude/rules/architecture.md` の判断表を引く。

### 設計判断・トレードオフ

- 判断ごとに採用案・却下案・理由を書く。少なくとも 2 案を提示し、推奨を明示する。
- 案が 3 つ以上のときは各案を `####` 見出しに昇格する。

### データフロー図 / シーケンス図

- Mermaid ブロック。図の直前に 1 行のキャプションを置く。
- 同期呼び出しには対応する戻り矢印を必ず描く。

## Severity Matrix

`architect` uses this matrix when self-checking before declaring the design phase done. Style findings always route to `architect` (the documents are wholly architect-owned).

| Observation | Severity |
|---|---|
| Design document contains a full type signature, an error `enum` definition, or a SQL/DDL body | 🔴 |
| Design document contains a docstring draft | 🔴 |
| クレート設計書ディレクトリに `README.md` 入口がない | 🔴 |
| 基本設計書 (`docs/design/overview/`) が必要な変更で作成・更新されていない | 🔴 |
| クレート種別のテンプレートで必須の topic が欠落している | 🔴 |
| トレードオフが 2 案未満、または推奨を欠く | 🔴 |
| Enumeration of 2+ items written as prose instead of a bulleted list | 🔴 |
| Multiple sentences on a single line without `  ` hard-break | 🔴 |
| Use Case / Port 見出しが `### UC-<N>:` / `### P-<N>:` 等の ID 接頭辞付き | 🔴 |
| Port が種別 / 配置レイヤーの注記なしで導入されている | 🟡 |
| Use case が入出力の概要またはエラー方針を欠く | 🟡 |
| 用語が表でなく箇条書きで書かれている | 🟡 |
| Top-level bullet whose subject is a code identifier instead of a role / behavior | 🟡 |
| Parenthetical packing 3+ related identifiers instead of sub-bullets | 🟡 |
| Coined kanji compound, direct-translation calque, or forced kanji for an industry-standard katakana term | 🟡 |
| Section with 3+ thematic subgroups uses prose lead-ins instead of `###` sub-headings | 🟡 |
| シーケンス図 lacks a one-sentence caption OR has unpaired call/return arrows | 🟡 |
| Lead-in sentence longer than one sentence | 💭 |
