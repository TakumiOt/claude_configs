---
paths:
  - "**/*.{rs,py,ts,tsx,js,jsx,mjs,cjs,go,java,kt,rb,cs,cpp,c,h,hpp,scala}"
---

# Docstring and Comment Guidelines

Authoritative rules for docstrings and code comments. Auto-load when Claude touches source files matching the `paths:` above, and also loaded on demand by the `developer` (when writing) and `code-reviewer` (when reviewing) agents via `Read`.

## Core Principle: Document Only What the Code Cannot Say

A docstring earns its place only when it carries information the reader cannot recover from the code itself — the name, signature, types, and the immediately surrounding code (including call sites). Self-evident elements get **no docstring**: absence is better than restating the obvious, because noise docstrings dilute the ones that matter and rot silently.

**Types first, docstrings second** — a rule that can be enforced by the type system, validation, or construction-time logic is expressed there first (invalid states unrepresentable, per `~/.claude/rules/architecture.md` Entity-layer rules); a docstring or comment covers only the residue the types cannot express.

**Write a docstring when at least one of these holds** (then it is REQUIRED, not optional):

- **Error conditions** — which failures occur under which conditions; an error-returning signature reveals at most the error type, never the triggering conditions.
- **Invariants / preconditions** — valid ranges, required call ordering, units, or parameter meaning that the type does not encode.
- **Side effects** — I/O, state mutation, external calls, blocking, or concurrency / cancellation behavior that the name does not advertise.
- **Domain meaning of an abstraction** — ports and domain concepts whose whole point is the promise they make; the contract is not recoverable from any single implementation.
- **Surprising behavior** — anything a reasonable reader would guess wrong from the name and signature.

**Skip the docstring when none of the above holds** — typical cases:

- The name, signature, and types say everything (simple constructors, accessors, DTOs with self-describing fields, obvious type aliases).
- The element is a thin delegation whose behavior is evident from the code it calls.
- Reading the immediate call sites gives full understanding.

The necessity judgement is the `developer`'s call at write time. `code-reviewer` checks both directions: a needed docstring that is missing, and a noise docstring that should be deleted.

## Quality Rules (for docstrings that are written)

- **English** — docstrings, identifiers, and code examples; regardless of spec-document or chat language.
- **Summary is one line** — what the element is or promises, not how it is implemented.
- **State only the non-obvious part** — do not pad with parameters or return values that are self-describing; cover exactly the information that justified writing the docstring.
- **Bullets for enumerations of 2+** (error variants, preconditions, cases) — never a prose paragraph.
- **Purpose over history** — a sentence of "why this exists" is welcome when the purpose is not obvious; alternatives-considered and migration history belong in an ADR or `git`, never in the docstring.

## Body Comments

- Inline comments explain **why**, never what. No prefix convention — state the reason as a plain comment in the language's comment syntax, not a labeled one (`Why: ...`).
- Implementation-mechanic rationale (why a generated implementation was chosen, why a defensive copy is taken, why error detail is dropped at a boundary) lives in a body comment next to the code — not in the docstring, which states the caller-facing information.
- No commented-out code. TODO/FIXME only with a linked issue/ticket (per the Definition of Done).

## Module-Level Overviews (conditional)

A module-level overview docstring is required only when **multiple public items interact** and the module only makes sense as a whole — e.g. a group of paired ports, a production implementation plus its test double, or a set of types that implement one protocol together. It states what the module provides, how the items relate, and any rationale shared by several items (stated once here, not repeated per item).

Modules with a single public item, or whose item set is self-evident, need no overview.

## Ports (Special Rules)

Ports are the prime "must document" case — the contract IS the abstraction. A port is expressed as the language's abstraction construct (Rust: trait; elsewhere: interface / protocol / abstract class).

- **Interface level**: What the domain expects from this port — the abstract promise — never infrastructure details.
- **Method level**: The domain meaning of each failure mode (not the underlying infrastructure error), plus any ordering or precondition the caller must uphold.

## Self-Contained: No External-Artifact References

A docstring (or body comment) must convey its reasoning from within the code — do **not** cite ADR numbers, spec-document paths, phase names, ticket IDs, or commit hashes as load-bearing context. Write the reasoning itself ("so integration tests can substitute doubles at assembly time"), not the pointer ("per ADR-0006"). External documents have a different lifetime than the code; a docstring that depends on them rots while the code keeps compiling. Within-unit references (item → module overview, trait method → trait docs) are fine — they render together and travel with the code.

## Grounded in the Implementation

Spec documents (`docs/spec/`) are basic design and carry no docstring drafts. Docstrings are written from scratch in the code and must reflect what the implementation actually does — including constraints discovered during coding (failure conditions, concurrency assumptions, call ordering). Do not transcribe spec wording.

## Prohibited

- A docstring on a self-evident element (restates the signature or type name, e.g. "Takes a user ID and returns a user") — delete it.
- A docstring that omits the non-obvious information that justified its existence (e.g. present, but silent on error conditions or side effects).
- Non-English docstrings.
- ADR numbers, `docs/spec/**` paths, phase names, ticket IDs, or commit hashes as load-bearing context.
- Alternatives-considered or historical narrative (belongs in an ADR / `git`).
- An enumeration of 2+ errors / preconditions / cases written as a prose paragraph instead of bullets.
- Labeled comment prefixes (`Why:`, `NOTE:` as a mandated format) — plain why-comments only.

## Severity Matrix

`code-reviewer` applies these severities verbatim — do not re-derive them.

| Finding | Severity |
|---|---|
| Missing docstring on an element with non-obvious error conditions, invariants, side effects, or surprising behavior | 🔴 blocker |
| Port interface or port method without a docstring stating its domain promise | 🔴 blocker |
| Port docstring leaking infrastructure details into the inner layer | 🔴 blocker |
| Docstring written in a language other than English | 🔴 blocker |
| Docstring (or body comment) citing an ADR number, spec-doc path, phase name, ticket ID, or commit hash as load-bearing context | 🔴 blocker ("external-reference rot") |
| Noise docstring on a self-evident element (restates signature / type name) — flag for deletion | 🟡 suggestion |
| Docstring present but missing the non-obvious information it should carry (error conditions, side effects, preconditions) | 🟡 suggestion |
| Missing module overview where multiple public items interact and only make sense together | 🟡 suggestion |
| History / alternatives narrated in a docstring instead of an ADR / `git` | 🟡 suggestion |
| Enumeration of 2+ errors / preconditions / cases written as prose instead of bullets | 🟡 suggestion |
| Same rationale repeated across symmetric items instead of stated once in the module overview | 💭 nit |
| Summary longer than one line | 💭 nit |
