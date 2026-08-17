#!/usr/bin/env bash
# PreToolUse hook: enforce the task-runner rule in ~/.claude/CLAUDE.md
# "Definition of Done" item 3 — Rust projects use cargo-make, never bare cargo.
# Blocks bare cargo subcommands that have cargo-make equivalents
# (build / test / run / check / clippy / fmt / bench / doc / nextest / clean)
# and tells the agent to use `cargo make <task>` instead.
# `cargo make ...` itself and other subcommands (metadata, tree, add via the
# dependency-approval flow, etc.) pass through untouched.
# Registered in ~/.claude/settings.json under hooks.PreToolUse with matcher "Bash".
# Exit 2 blocks the command and feeds stderr back to the agent.

input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -z "$command" ] && exit 0

# Only inspect commands that invoke cargo as a command word.
printf '%s' "$command" | grep -Eq '(^|[^[:alnum:]_.-])cargo([[:space:]]|$)' || exit 0

# Match `cargo <sub>` with an optional toolchain selector (`cargo +nightly <sub>`).
blocked='(^|[^[:alnum:]_.-])cargo[[:space:]]+(\+[^[:space:]]+[[:space:]]+)?(build|b|test|t|run|r|check|c|clippy|fmt|bench|doc|d|nextest|clean)([[:space:]]|$)'
if printf '%s' "$command" | grep -Eq -- "$blocked"; then
  {
    echo "BLOCKED: bare cargo subcommand — this project standardizes on cargo-make."
    echo ""
    echo "Policy: ~/.claude/CLAUDE.md 'Definition of Done' item 3 (task runner green)."
    echo "Use the cargo-make task instead, e.g.:"
    echo "  cargo make build / cargo make test / cargo make lint"
    echo "Check Makefile.toml for the available tasks if unsure."
  } >&2
  exit 2
fi

exit 0
