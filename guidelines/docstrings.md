# Docstring Guidelines

Authoritative rules for docstrings on public API elements. Loaded on demand by the `developer` (when writing) and `code-reviewer` (when reviewing) agents.

## Scope

- **Required for**: every element visible across module boundaries — `pub` functions / methods / structs / enums / traits / type aliases / modules in Rust; `export`ed members or non-underscore / `__all__`-listed members in other languages.
- **Not required for**: private, `pub(crate)`, or narrower elements. Rely on naming and why-comments instead.
- **Language**: Docstrings MUST be written in **English**, regardless of the language used in design documents or user-facing chat. Identifiers, type names, and code examples are also English.

## Content Structure

Every public API docstring MUST follow this structure. Items 1 and 2 are mandatory; the rest are required when applicable.

1. **Summary (one line)** — A noun phrase describing *what the element is* (its role), not how it is implemented.
2. **Responsibility / Why** — Why this element exists and which use case or domain requirement it serves. Reference the relevant section of `docs/design/<feature>.md` when helpful.
3. **Contract**:
   - Meaning and preconditions of each parameter (invariants, valid ranges).
   - Meaning of the return value.
   - Error variants that may be returned and the conditions that trigger them.
4. **Side effects** — I/O, state mutation, external calls, concurrency expectations. If none, state "Pure" explicitly.
5. **Example (optional)** — Only for traits or public functions whose intended usage is non-obvious.

## Port Traits (Special Rules)

- **Trait level**: Describe what the domain expects from this port — the abstract contract — not infrastructure details.
- **Method level**: Input/output contract plus the *domain meaning* of each failure mode (not the underlying infrastructure error).

## Origin: Design Document Drafts

The `architect` agent produces Japanese docstring drafts in `docs/design/<feature>.md` under a `## Docstring 草案` section. The `developer` agent transcribes these into **English** docstrings in the code during implementation — this is the **starting point**, not the finish line.

The transcription task is complete only after the Why, contract, and error conditions have been **refined against the actual implementation**, adding any constraints discovered during coding (failure conditions, concurrency assumptions, required call ordering).

## Prohibited

- Docstrings that merely restate the signature in prose (e.g. "Takes a user ID and returns a user"). **A docstring without a Why is considered incomplete.**
- Descriptions obvious from the type name alone (e.g. "A function that does X", "A class for Y").
- Non-English docstrings on public API.
- Leaving the design-document draft as-is after implementation, without refining it against the code.

## Review Severity Matrix (for `code-reviewer`)

Apply these severities verbatim — do not re-derive them.

| Finding | Severity |
|---|---|
| Missing docstring on a public API element | 🔴 blocker |
| Docstring missing the **Why / Responsibility** (item 2) | 🔴 blocker ("incomplete docstring") |
| Docstring written in a language other than English | 🔴 blocker |
| Docstring that only restates the signature or repeats the type name | 🔴 blocker (counts as missing-Why) |
| Port-trait docstring leaking infrastructure details into the inner layer | 🔴 blocker |
| Missing **Contract** (parameter preconditions / return meaning / error variants) when applicable | 🟡 suggestion |
| Missing **Side effects** declaration (or explicit "Pure") | 🟡 suggestion |
| Missing **Example** on a non-obvious trait or public function | 🟡 suggestion |
| Port-trait method docstring that documents infrastructure errors instead of domain meaning | 🟡 suggestion |
| Unmodified transcription from `docs/design/<feature>.md` when the implementation has revealed additional constraints not yet reflected | 🟡 suggestion ("stale docstring — refine against implementation") |
