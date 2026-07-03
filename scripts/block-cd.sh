#!/usr/bin/env bash
# PreToolUse hook: block `cd` / `pushd` in Bash commands (applies to main agent + all subagents).
# Registered in ~/.claude/settings.json under hooks.PreToolUse with matcher "Bash".
# Invoked automatically by the harness before every Bash tool call; the tool-call JSON
# arrives on stdin. Exit 2 blocks the command and feeds stderr back to the agent.
command="$(jq -r '.tool_input.command // empty')"
[ -z "$command" ] && exit 0

# Match `cd` / `pushd` only as a command word: at start, or after a shell operator / space / quote / paren.
# Excludes word-chars and `.` before it, so `cdk`, `abcd`, `foo.cd`, `pushdir` are NOT matched.
if printf '%s' "$command" | grep -Eq '(^|[^[:alnum:]_.])(cd|pushd)([[:space:]]|$)'; then
  {
    echo "BLOCKED: this command tries to change the working directory (cd / pushd)."
    echo ""
    echo "This is a deliberate project policy, not a technical limitation:"
    echo "every command runs from the session's current directory."
    echo "Do NOT try to achieve the directory change another way — pushd/popd,"
    echo "bash -c 'cd ...', subshells (cd ...), env --chdir, make's --directory"
    echo "used purely to relocate, etc. all violate the same policy."
    echo ""
    echo "Instead, re-run the SAME command rewritten to run from here:"
    echo "  - file ops / search : pass the directory as an argument (rg PATTERN <dir>/, ls <dir>)"
    echo "  - git               : git -C <dir> <subcommand>"
    echo "  - cargo / cargo make: run from the workspace root as-is (they are workspace-aware);"
    echo "                        use --manifest-path <dir>/Cargo.toml only when targeting one crate"
    echo "  - make              : make -C <dir> <target>"
    echo "  - npm / pnpm        : npm --prefix <dir> ... / pnpm -C <dir> ..."
    echo ""
    echo "If your tool genuinely has no way to target another directory, STOP and"
    echo "report that to the user instead of changing directory."
  } >&2
  exit 2
fi
exit 0
