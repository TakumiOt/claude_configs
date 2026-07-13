# Specification Document Style Rules

Single source of truth for the structure and visual style of `docs/spec/` — the **living specification** of the system. `architect` writes and reconciles the documents and self-checks against the Severity Matrix at the bottom before declaring a phase done. A future spec-reviewer (and `pr-reviewer` at the merge gate) grades against the same matrix.

This file replaces the former design-document model: there is no separate "frozen design doc". The spec is one continuously-maintained artifact, touched at two workflow points — drafted forward at design time, reconciled backward at merge time (see "Living Specification" below).

## Precedence

This file wins over style sections in `~/.claude/agents/architect.md`. It loses to `~/.claude/rules/architecture.md` (technical principles like layer responsibilities and port placement) — those are domain-of-truth rules, while this file governs document presentation.

This file is **independent of** `~/.claude/rules/pr-style.md`. The two address different audiences and lifecycles; rules are not transitively inherited.

## Scope

Applies to every Markdown file under `docs/spec/`. Three kinds of documents:

- **全体仕様** (`docs/spec/overview/`) — the system-wide specification. Why the system exists, who uses it, what capabilities it provides, how the crates map to those capabilities. One per repository.
- **機能領域仕様** (`docs/spec/<capability>/`) — one directory per capability (a user-observable feature / behavior the system promises). The canonical axis of the spec.
- **横断・技術仕様** (`docs/spec/_platform/`, and similar cross-cutting dirs) — cross-cutting technical concerns that are real but are not user-facing capabilities (infrastructure platform, shared kernel).

`タスク分解` is **not** a spec document. It lives in a `docs/tasks/<work-name>/` directory (a README backlog index plus one PBI file per slice) with its own format defined in `~/.claude/agents/architect.md`, and is not governed by this file.

ADR files (`docs/adr/<NNNN>-<title>.md`) and PR files (`docs/pr/**`) follow their own templates and are not covered here.

## Core Principle: Living Specification

The spec describes **what the system does and promises right now** — not "how we decided to build it". Two consequences drive everything else.

### 時計の分離 (separate the clocks)

Three kinds of information have three different lifetimes; mixing them is what makes a document rot. Keep each in its home.

| 情報 | 寿命 | 置き場所 |
|---|---|---|
| なに/どう — 現在の振る舞い・制約・データの意味 | 常に最新 | `docs/spec/`(この文書群) |
| なぜ — 理由・トレードオフ・代替案・移行の歴史 | 時点固定・追記のみ | `docs/adr/` |
| この変更で何が変わったか — 差分 | 使い捨て | `docs/pr/` |

- 仕様書には**理由を書かない**。判断の背景は ADR に置き、相対リンクで参照する。
- 「A案を採用しB案を却下した」のような時点固定の語りを仕様書に残すと、読む頃には選択肢自体が陳腐化して半分が腐る。

### 設計時に前向き、マージ時に後ろ向き

- 設計時(Phase 1): `architect` がブランチ上で仕様書を編集し、**この作業後にシステムが約束する目標状態**を書く。これが要件定義のベースラインも兼ねる。
- マージ時(Phase 3 / DoD ゲート): 実装確定後に仕様書を実態と突き合わせ、**ブランチの仕様 == ブランチの振る舞い**になるよう補正する。
- git が「現在(`main`)」と「目標(ブランチ)」を分離するので、ステータス注記や「未実装」マーカーは不要。

### 基本設計どまり (detailed design lives in code)

仕様書は機能領域・振る舞いの粒度で書く。詳細設計はコードが真実の源。以下は書かない。

- 型シグネチャの全文(`fn` シグネチャ・構造体フィールド一覧・トレイトメソッド本体)。
- エラー `enum` 定義(variant ごとのコードブロック)。
- SQL / DDL / マイグレーション本体。
- docstring の下書き。

名前と役割で参照し、詳細はコードを真実の源として扱う。

## Language

- Document body: Japanese. README.md も含め、`docs/spec/` 配下の本文はすべて日本語。
- Code identifiers, file paths, type names, code snippets: native form (English / project-native), kept in backticks or fenced code blocks.
- No JP/EN code-mixing, no forced kanji translations of industry-standard katakana, no coined kanji compounds, no direct-translation calques. Full rule and substitutions in `~/.claude/CLAUDE.md` "Language & Documentation Policy".
- **Do not use the bare word 「契約」/`contract`.** It names neither the *kind* of guarantee (error conditions / invariants / pre- & post-conditions / ordering / wire format / trait bounds) nor the *subject* (which port / function / type). Qualify both (e.g. 「`SystemInfoProvider` が OS リソース観測を抽象する Gateway である旨」, 「`# Errors` が示すエラー条件」) or state the guarantee concretely (e.g. 「無効な PUT が現行値を破壊しない」). Acceptable only in conceptual/meta prose discussing the notion of contracts itself.
- This rule file: English (per `~/.claude/CLAUDE.md` Rules Directory Governance §6).

## Core Rule: Bullets First

**Bullets are the default and dominant format. Prose is the exception.**

Prose is permitted ONLY for:

1. A single short lead-in sentence framing a bullet list.
2. Trade-off analysis where a reasoned narrative is genuinely clearer than bullets (rare; usually still bulleted, and usually belongs in an ADR).
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

## README Convention (per-directory)

`docs/spec/` 配下の**すべてのディレクトリ**は `README.md` を入口として持つ。README はそのディレクトリの「地図」であり、何を置くべきかをそこを開いた人に伝える。

- **言語**: 日本語(本文ポリシーと同じ)。
- すべての README が必ず含むもの:
  - **目的・責務** — このディレクトリが何を扱うか(3 bullets 程度)。
  - **収録方針** — このディレクトリに**置くべきドキュメントと置くべきでないドキュメント**を明示する。各ファイルの役割を「ファイル名 → 何を書くか」の対応で示す。
  - **目次** — 配下のファイル / サブディレクトリへの相対 Markdown リンク。
- **`docs/spec/README.md`(仕様書ツリーの最上位)** は上記に加えて以下を持つ:
  - 仕様書全体の構造(`overview/` = 全体仕様、`<capability>/` = 機能領域仕様、`_platform/` = 横断・技術仕様)。
  - 時計の分離方針(仕様書 / ADR / PR の住み分け)を 1 度だけ宣言し、各機能領域仕様はそれを繰り返さない。
  - 機能領域一覧(各 `<capability>/` への相対リンク)。
- README は**収録方針を述べる場所**であって、振る舞いそのものを書く場所ではない。具体的な振る舞いは各テンプレートファイルに置く。

## Document Structure

### 全体仕様 — `docs/spec/overview/`

Across its files, the system-wide spec MUST cover:

- システムの目的・責務 — why the system exists, the capability it delivers, what it does NOT do.
- 想定ユーザー — the actors and how they authenticate.
- ユーザーごとのユースケースと権限 — what each actor can do.
- 機能領域一覧 — the capabilities the system provides (each links to its `docs/spec/<capability>/`).
- クレート構成と依存グラフ — the crate list and their dependency edges.
- 機能領域とクレートのマッピング — どの機能領域をどのクレート群が実装するか(機能領域横断の全体像)。
- データフロー図 — the major flows that cross crates.
- システム全体の設計判断 — `../adr/README.md`(唯一の ADR 索引)へのリンク (理由の本文は ADR 側; overview 側で索引を二重管理しない)。

Recommended file layout: `README.md`(目的・責務・想定ユーザー・機能領域一覧・収録方針・目次)/ `use-cases.md` / `architecture.md`(構成・依存グラフ・機能領域マッピング・データフロー)。ADR の索引は `docs/adr/README.md` に一本化し、ここからリンクする。

### 機能領域仕様 — `docs/spec/<capability>/`

One directory per capability. `<capability>` は安定した機能領域記述子の kebab-case(マーケティング上の機能名ではなく、システムが約束する機能領域の名前)。

- `README.md` — 目的・この機能領域が何を約束するか・スコープ(扱う / 扱わない)・関連する機能領域・収録方針・目次。
- `behavior.md` — ユースケース / 振る舞い。各々の名前(自然な関数名)・目的・入出力の概要・エラー方針。
- `data-and-constraints.md` — 不変条件・データの意味(用語集・永続化テーブルの用途)。DDL / 型シグネチャは書かない。
- `implementation-map.md` — この機能領域を実装するクレート / ポートへの薄いポインタ(相対リンク)。「どこを読めばコードに辿り着くか」を示す。

A capability whose data model is trivial may merge `data-and-constraints.md` into `behavior.md`; the README states the reason. The README entry point is always required.

### 横断・技術仕様 — `docs/spec/_platform/`(および同種の横断ディレクトリ)

- `README.md` — 扱う横断的関心の一覧と収録方針・目次。
- `port-implementations.md` — 実装する全ポートの一覧(機能領域別)と永続化基盤。
- `boundary-policy.md` — 境界変換(フレームワーク例外 → ドメインエラー)と識別子変換のポリシー。
- `platform.md` — マイグレーション基盤・ロギング・デプロイ前提などの技術基盤。

Internal file splitting beyond a template is at the architect's discretion based on size; a small directory may merge files, but the `README.md` entry point with 収録方針 + 目次 is always required. Cross-directory references use relative Markdown links.

## Per-Section Style

### 目的・責務 / スコープ / 連携

- 3 bullets 程度を上限とする。全体仕様や ADR の内容を重複させず、リンクで参照する。
- 連携は依存先 / 依存元 / 外部 Actor を箇条書きまたは表で示す。

### ユースケース / 振る舞い

- 振る舞いごとに `##` 見出し。見出しは実装で使う自然な関数名(`### UC-<N>:` のような ID 接頭辞は禁止)。
- 入出力は概要のみ。DTO の全フィールドや型シグネチャは書かない。
- エラーは方針(どの条件で何を返すか・どの HTTP ステータスに対応するか)を書く。`enum` 定義は書かない。

### データとモデル

- 集約・エンティティ・値オブジェクトは「名前・役割・主要な不変条件」を表で示す。型定義の全文は書かない。
- 永続化されるデータはテーブル名と用途を示す。DDL は書かない。
- 用語は Markdown 表 (`| 用語 | 定義 |`) で示す。

### インターフェース / ポート

- ポートは「名前・種別 (Repository / Gateway / QueryService)・配置レイヤー・抽象する対象」を表で示す。メソッドシグネチャは書かない。
- 配置レイヤーの根拠として `~/.claude/rules/architecture.md` の判断表を引く。

### 設計判断

- 仕様書には**判断の結果(現在どうなっているか)**だけを書き、理由・却下案・トレードオフは ADR に置いて相対リンクで参照する。
- 仕様書内に採用案 / 却下案の比較表や「なぜこの設計か」の語りを書かない(時計違反)。

### データフロー図 / シーケンス図

- Mermaid ブロック。図の直前に 1 行のキャプションを置く。
- 同期呼び出しには対応する戻り矢印を必ず描く。

## Reconcile Discipline

The spec is alive only because the workflow forces it current. This is the make-or-break rule.

- マージ時(Phase 3)に、PR の「仕様からの変更点」差分を仕様書へ反映し、**ブランチの仕様 == ブランチの振る舞い**にする。
- `pr-reviewer` は DoD ゲートとして**仕様書と実装の整合**を必須チェックする。乖離は 🔴。
- 機能領域が分割 / 統合されたら、`docs/spec/README.md` の機能領域一覧とディレクトリ構成を同じ変更で更新する(リンク切れを残さない)。
- 仕様書が `main` の現実と一致しない記述を含むのは陳腐化であり、reconcile 漏れとして扱う。

## Severity Matrix

`architect` uses this matrix when self-checking; `pr-reviewer` uses it at the merge gate. Style and reconcile findings route to `architect` (the documents are wholly architect-owned).

| Observation | Severity |
|---|---|
| Spec contains a full type signature, an error `enum` definition, or a SQL/DDL body | 🔴 |
| Spec contains a docstring draft | 🔴 |
| Spec contains rationale / trade-off / rejected-alternative narrative that belongs in an ADR (時計違反) | 🔴 |
| 仕様書の記述が `main` の実装と乖離している(reconcile されていない) | 🔴 |
| `docs/spec/` 配下のディレクトリに `README.md` 入口がない | 🔴 |
| `README.md` が収録方針(何を置くべきか)を記述していない | 🟡 |
| 全体仕様 (`docs/spec/overview/`) が必要な変更で作成・更新されていない | 🔴 |
| 機能領域仕様テンプレートで必須の topic が欠落している | 🔴 |
| Enumeration of 2+ items written as prose instead of a bulleted list | 🔴 |
| Multiple sentences on a single line without `  ` hard-break | 🔴 |
| Use Case / 振る舞い見出しが `### UC-<N>:` 等の ID 接頭辞付き | 🔴 |
| Port が種別 / 配置レイヤーの注記なしで導入されている | 🟡 |
| Use case が入出力の概要またはエラー方針を欠く | 🟡 |
| 用語が表でなく箇条書きで書かれている | 🟡 |
| Top-level bullet whose subject is a code identifier instead of a role / behavior | 🟡 |
| Parenthetical packing 3+ related identifiers instead of sub-bullets | 🟡 |
| Coined kanji compound, direct-translation calque, or forced kanji for an industry-standard katakana term | 🟡 |
| Bare 「契約」/`contract` with neither the kind of guarantee nor the subject qualified (outside conceptual/meta prose) | 🟡 |
| Section with 3+ thematic subgroups uses prose lead-ins instead of `###` sub-headings | 🟡 |
| シーケンス図 lacks a one-sentence caption OR has unpaired call/return arrows | 🟡 |
| Lead-in sentence longer than one sentence | 💭 |
