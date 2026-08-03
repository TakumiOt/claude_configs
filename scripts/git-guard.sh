#!/usr/bin/env bash
# PreToolUse hook: enforce the git policy in ~/.claude/CLAUDE.md "Git Operations"
# (applies to main agent + all subagents).
# The settings.json allow/ask/deny lists handle subcommand-level permissions; this
# hook blocks what prefix matching cannot express: flag-level bypass vectors
# (--no-verify, git -c, --amend, --force), bulk staging, writes to the
# protected git-flow branches (main / master / develop / release/* / hotfix/*),
# and the gh review workflow (merge / ready / close; PRs must be drafts).
# Registered in ~/.claude/settings.json under hooks.PreToolUse with matcher "Bash".
# Exit 2 blocks the command and feeds stderr back to the agent.
# Note: patterns match the raw command string, so a commit message that contains a
# blocked flag can false-positive — reword the message and retry.

input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -z "$command" ] && exit 0

# Only inspect commands that invoke git or gh as a command word.
is_git=0
is_gh=0
printf '%s' "$command" | grep -Eq '(^|[^[:alnum:]_.-])git([[:space:]]|$)' && is_git=1
printf '%s' "$command" | grep -Eq '(^|[^[:alnum:]_.-])gh([[:space:]]|$)' && is_gh=1
[ "$is_git" = 0 ] && [ "$is_gh" = 0 ] && exit 0

has() { printf '%s' "$command" | grep -Eq -- "$1"; }

block() {
  {
    echo "BLOCKED: $1"
    echo ""
    echo "Policy: ~/.claude/CLAUDE.md 'Git Operations'."
    echo "$2"
  } >&2
  exit 2
}

# --- gh policy: draft PR creation only; review workflow stays user-owned ------
if [ "$is_gh" = 1 ]; then
  has '(^|[^[:alnum:]_.-])gh[[:space:]]+pr[[:space:]]+(merge|ready|close)([[:space:]]|$)' && block \
    "gh pr merge / ready / close are the user's review workflow." \
    "Report the PR URL and let the user review, mark ready, and merge."
  has '(^|[^[:alnum:]_.-])gh[[:space:]]+repo[[:space:]]+delete([[:space:]]|$)' && block \
    "deleting repositories is prohibited." \
    "Report it and let the user manage repositories."
  if has '(^|[^[:alnum:]_.-])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
    has '--draft([[:space:]=]|$)|[[:space:]]-d([[:space:]]|$)' || block \
      "gh pr create without --draft is prohibited." \
      "PRs are always opened as drafts: gh pr create --draft ... The user marks them ready after review."
    has '--body-file([[:space:]=]|$)|[[:space:]]-F([[:space:]]|$)' || block \
      "gh pr create without --body-file is prohibited." \
      "The PR body is the PR document: gh pr create --draft --body-file docs/pr/<feature>/<N>-<aggregation>.md — never a hand-written body."
  fi
  if has '(^|[^[:alnum:]_.-])gh[[:space:]]+pr[[:space:]]+edit([[:space:]]|$)'; then
    has '--body([[:space:]=]|$)|[[:space:]]-b([[:space:]]|$)' && block \
      "gh pr edit with an inline --body is prohibited." \
      "The PR body always comes from the PR document: gh pr edit <number> --body-file docs/pr/<feature>/<N>-<aggregation>.md"
  fi
fi

[ "$is_git" = 0 ] && exit 0

# --- Hook / config bypass vectors --------------------------------------------
has '--no-verify' && block \
  "--no-verify bypasses pre-commit/pre-push hooks." \
  "Hooks are a mandatory safety layer. If a hook fails, fix the cause or report it to the user — never bypass it."
has 'commit[^|;&]*[[:space:]]-[[:alpha:]]*n' && block \
  "'git commit -n' is --no-verify in disguise." \
  "Run the commit without -n. If the flag was inside your commit message text, reword the message."
has '(^|[^[:alnum:]_.-])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+-c([[:space:]]|=)' && block \
  "inline config override (git -c) can disable safety config such as hooks." \
  "Run the plain git command; if a config change is genuinely needed, ask the user."
has 'core\.hooksPath|GIT_CONFIG|GIT_DIR=|--git-dir|--work-tree' && block \
  "overriding git config, the hooks path, or the repo location is prohibited." \
  "Ask the user if such a change is genuinely needed."

# --- History rewriting / force flags ------------------------------------------
has '--amend' && block \
  "commit --amend rewrites history." \
  "Make a new commit instead, or report the fix and let the user rewrite history themselves."
has '--force(-with-lease|-if-includes)?([[:space:]=]|$)' && block \
  "force flags are prohibited on every git subcommand." \
  "Report why a force operation seems needed and let the user run it."

# --- Staging discipline (stage explicitly by path) -----------------------------
has 'add[^|;&]*[[:space:]](-[[:alpha:]]*[Au][[:alpha:]]*|--all|--update)([[:space:]]|$)' && block \
  "bulk staging (git add -A / -u / --all) is prohibited." \
  "Review git status, then stage explicitly by path: git add <path>..."
has 'add([[:space:]]+[^|;&[:space:]]+)*[[:space:]]+\.{1,2}/?([[:space:]]|$)' && block \
  "staging '.' (a whole directory) is prohibited." \
  "Stage explicitly by path: git add <path>..."
has 'commit[^|;&]*[[:space:]]-[[:alpha:]]*a' && block \
  "'git commit -a' auto-stages every tracked file." \
  "Stage explicitly by path with git add <path>..., then commit."

# --- Protected branches (git flow: main / master / develop) --------------------
# Determine the repo the command targets: explicit `git -C <dir>`, else the cwd.
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
repo="$(printf '%s' "$command" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')"
[ -z "$repo" ] && repo="$cwd"
branch=""
[ -n "$repo" ] && branch="$(git -C "$repo" branch --show-current 2>/dev/null)"

if has '(^|[^[:alnum:]_.-])git[[:space:]]([^|;&]*[[:space:]])?(commit|push)([[:space:]]|$)'; then
  case "$branch" in
    main | master | develop | release/* | hotfix/*)
      block "current branch '$branch' is protected (git flow): no direct commit or push." \
        "Create a work branch first: git switch -c feature/<descriptor> develop"
      ;;
  esac
fi

if has '(^|[^[:alnum:]_.-])git[[:space:]]([^|;&]*[[:space:]])?push([[:space:]]|$)'; then
  has 'push[^|;&]*[[:space:]:](main|master|develop|release/[^[:space:]]+|hotfix/[^[:space:]]+)([[:space:]]|$)' && block \
    "pushing to a protected branch (main / master / develop / release/* / hotfix/*) is prohibited." \
    "Only feature/* branches are pushed; flow branches are the user's territory."
  has 'push[^|;&]*([[:space:]]--delete([[:space:]]|$)|[[:space:]]:[^[:space:]])' && block \
    "deleting remote refs via push is prohibited." \
    "Report the cleanup need and let the user delete branches."
fi

# --- Destructive branch / switch flags ------------------------------------------
has 'branch[^|;&]*[[:space:]](-[[:alpha:]]*[dDmMf][[:alpha:]]*|--delete|--move|--force|--copy)([[:space:]=]|$)' && block \
  "branch delete / rename / force is prohibited." \
  "Report it and let the user manage branches."
has 'switch[^|;&]*[[:space:]](-[[:alpha:]]*[fC][[:alpha:]]*|--force|--discard-changes|--force-create)([[:space:]=]|$)' && block \
  "switch with force / discard flags can destroy local changes." \
  "Use plain git switch <branch>, or git switch -c feature/<descriptor> develop."

exit 0
