---
paths:
  - "**/*.{rs,py,ts,tsx,js,jsx,mjs,cjs,go,java,kt,rb,cs,cpp,c,h,hpp,scala}"
---

# Docstring Guidelines

Authoritative rules for docstrings on public API elements. Auto-load when Claude touches source files matching the `paths:` above, and also loaded on demand by the `developer` (when writing) and `code-reviewer` (when reviewing) agents via `Read`.

## Scope

- **Required for**: every element visible across module boundaries — `pub` functions / methods / structs / enums / traits / type aliases / modules in Rust; `export`ed members or non-underscore / `__all__`-listed members in other languages.
- **Not required for**: private, `pub(crate)`, or narrower elements. Rely on naming and why-comments instead.
- **Language**: Docstrings MUST be written in **English**, regardless of the language used in specification documents or user-facing chat. Identifiers, type names, and code examples are also English.

## Core Rule: Concise, Bullets First

A docstring is reference material a reader skims, not an essay. Keep it tight and move long rationale to its proper home (see "Where Each Why Lives" below).

- **Summary is always one line** — a noun phrase, never two sentences.
- **Why is one or two sentences** stating purpose — not a narrative of history or alternatives.
- **Contract, error variants, and side effects are bulleted** when they enumerate 2+ things — never a prose paragraph.
- **Prose is the exception**, permitted only for: the one-line summary, the one-to-two-sentence Why, and a single short lead-in framing a bullet list.

Prose is PROHIBITED for: enumerating 2+ parameters / errors / cases, walking through reasons or consequences in paragraph form, or narrating implementation mechanics. This mirrors the "Bullets First" rule `pr-style.md` and `spec-style.md` already enforce.

## Module-Level Docstrings

Every module (and crate root) exposing public items MUST open with a module-level overview docstring, in the spirit of the Rust standard library's module pages. Language-specific syntax (Rust's `//!` placement) lives in `~/.claude/rules/rust.md`.

- **What the module provides** — the capability and the set of public items that deliver it, described as a whole rather than item-by-item.
- **How the items relate** — orient the reader (e.g. production implementation vs. test double, paired sign / verify ports).
- **Cross-cutting Why** — rationale shared by several items in the module is stated HERE, once; item docstrings then carry only what is specific to them and refer back to this overview by role.

The module overview is the one place a richer explanation is welcome; item docstrings stay short because the shared context already lives above them.

## Content Structure

Every public API docstring MUST follow this structure. Items 1 and 2 are mandatory; the rest are required when applicable.

1. **Summary (one line)** — A noun phrase describing *what the element is* (its role), not how it is implemented.
2. **Responsibility / Why** — Why this element exists and which use case or domain requirement it serves, in **one or two sentences**. Inline the reasoning, OR — when the same rationale is shared by several items in the module — state it once in the module overview and let each item refer to it by role (see "Where Each Why Lives" below). Never delegate to an external document (ADR / spec doc / ticket); longer history and alternatives-considered belong in an ADR or `git`, not here.
3. **Contract**:
   - Meaning and preconditions of each parameter (invariants, valid ranges).
   - Meaning of the return value.
   - Error variants that may be returned and the conditions that trigger them.
4. **Side effects** — I/O, state mutation, external calls, concurrency expectations. If none, state "Pure" explicitly.
5. **Example (optional)** — Only for traits or public functions whose intended usage is non-obvious.

## Where Each "Why" Lives

The Why is mandatory, but it has four kinds — each with a different home. Splitting them is what keeps any single docstring short while preserving the reasoning.

| Kind of Why | Example | Home |
|---|---|---|
| Why the module / abstraction exists; how its items relate | "all time reads funnel through one port so tests can pin time" | Module overview docstring (once) |
| Why an item exists / which use case it serves | "mints short-lived JWTs after API-key authentication" | Item docstring — one or two sentences |
| Why a specific implementation mechanic was chosen | "zero-sized, so `Copy` avoids `Arc` indirection" | A `// why` body comment next to the code |
| Why this design beat the alternatives; historical migration | trade-off analysis, "what we tried before" | ADR / `git blame` — NOT a docstring |

- **Item Why states purpose, not history** — the longer "why this way and not that way" goes to an ADR, reachable via `git blame`, never pasted into the docstring.
- **Implementation mechanics go in `// why` body comments** — derive choices, zero-sizing, dropping error detail at a boundary, cfg-gating mechanics. These explain code a maintainer reads, not a contract a caller depends on, so they stay out of the public docstring.
- **Shared Why is stated once** in the module overview — symmetric items (paired ports, blanket impls, a production impl plus its test double) refer to it rather than each repeating it.

## Port Traits (Special Rules)

- **Trait level**: Describe what the domain expects from this port — the abstract contract — not infrastructure details.
- **Method level**: Input/output contract plus the *domain meaning* of each failure mode (not the underlying infrastructure error).

## Writing Docstrings From Basic Design

Specification documents (`docs/spec/`) are **basic design** — they state each port's role, each error's domain meaning, and the layer contracts, but they do **not** contain docstring drafts. The `developer` agent writes every docstring **from scratch** in the code, in English, using the spec document as context for the *Why* and the contract — not as text to transcribe.

A docstring is complete only after the Why, contract, and error conditions are **grounded in the actual implementation**, including any constraints discovered during coding (failure conditions, concurrency assumptions, required call ordering).

## Self-Contained: No External-Artifact References

Docstrings MUST convey their intent from within the code's own rendered docs, not from an artifact that lives outside the code. Two cases differ:

- **Within-unit references are allowed and encouraged** — an item MAY defer shared context to its module overview, and a trait method MAY defer to the trait-level docstring ("See the trait-level documentation."). These render together (e.g. `cargo doc`) and travel with the code, so the intent stays self-contained.
- **External-artifact references are prohibited** as load-bearing context — do **not** cite ADR numbers, spec-document paths, phase names, ticket IDs, or commit hashes.

- ADR numbers and phase names are **identifiers, not reasons** — strip them out and write the reasoning itself ("to allow integration tests to substitute test doubles at assembly time"), not the pointer ("per ADR-0006 / Phase 9e").
- External documents have a different lifetime than the code: ADRs get renumbered, spec documents get consolidated, phases finish. A docstring that depends on them rots silently while the code keeps compiling.
- The *purpose* of a docstring is that "reading the same place as the code conveys the design intent." Outsourcing that intent to another file defeats the purpose and creates duplicated maintenance cost.
- If the background is genuinely too long to inline, summarize the load-bearing reasoning in the docstring and let the reader find further history via `git blame` / commit messages — not via a hard-coded path in the docstring.

This rule applies to inline `// why` comments as well: write the *why*, not a pointer to where the *why* lives.

## Prohibited

- Docstrings that merely restate the signature in prose (e.g. "Takes a user ID and returns a user"). **A docstring without a Why is considered incomplete.**
- Descriptions obvious from the type name alone (e.g. "A function that does X", "A class for Y").
- Non-English docstrings on public API.
- A docstring that merely echoes the spec's basic-design wording without being grounded in the actual implementation.
- References to ADR numbers, `docs/spec/**` paths, phase names, ticket IDs, or commit hashes used as load-bearing context (see "Self-Contained" above).
- A multi-sentence narrative Why where one or two sentences suffice; alternatives-considered or historical migration narrated in an item docstring instead of an ADR / `git`.
- Implementation mechanics (derive choices, zero-sizing, cfg-gating, error-detail dropping) narrated in the public docstring instead of a `// why` body comment.
- The same rationale repeated across symmetric items instead of stated once in the module overview.
- An enumeration of 2+ parameters / errors / cases written as a prose paragraph instead of a bulleted list.
- A docstring claiming it "honors" / "preserves the contract" without naming the specific guarantee (error variants / invariant / call ordering / wire shape). "Contract" alone hides what the caller may rely on — name the concrete obligation. Fine in a module overview contrasting a port's *abstract contract* with concrete impls, where the concept itself is the subject.

## Severity Matrix

`code-reviewer` applies these severities verbatim — do not re-derive them.

| Finding | Severity |
|---|---|
| Missing docstring on a public API element | 🔴 blocker |
| Docstring missing the **Why / Responsibility** (item 2) | 🔴 blocker ("incomplete docstring") |
| Docstring written in a language other than English | 🔴 blocker |
| Docstring that only restates the signature or repeats the type name | 🔴 blocker (counts as missing-Why) |
| Port-trait docstring leaking infrastructure details into the inner layer | 🔴 blocker |
| Missing **Contract** (parameter preconditions / return meaning / error variants) when applicable | 🟡 suggestion |
| Docstring asserting it preserves "the contract" without naming the specific guarantee (error variants / invariant / ordering / etc.), outside conceptual module-overview prose | 🟡 suggestion |
| Missing **Side effects** declaration (or explicit "Pure") | 🟡 suggestion |
| Missing **Example** on a non-obvious trait or public function | 🟡 suggestion |
| Port-trait method docstring that documents infrastructure errors instead of domain meaning | 🟡 suggestion |
| Docstring (or `// why` comment) that cites an ADR number, spec-doc path, phase name, ticket ID, or commit hash as load-bearing context instead of inlining the reasoning | 🔴 blocker ("external-reference rot") |
| Docstring that echoes the spec's basic-design wording when the implementation has revealed additional constraints not yet reflected | 🟡 suggestion ("stale docstring — ground it in the implementation") |
| Item Why narrating history / alternatives instead of stating purpose (belongs in an ADR / `git`) | 🟡 suggestion |
| Implementation mechanics narrated in the docstring instead of a `// why` body comment | 🟡 suggestion |
| Enumeration of 2+ parameters / errors / cases written as prose instead of a bulleted list | 🟡 suggestion |
| Same rationale duplicated across symmetric items instead of stated once in the module overview | 🟡 suggestion |
| Summary longer than one line | 💭 nit |
