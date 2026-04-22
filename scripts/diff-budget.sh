#!/usr/bin/env bash
#
# diff-budget.sh — Count the budget-relevant diff size for a Vertical Slice.
#
# Canonical diff-line counter used by the architect / developer / code-reviewer
# agents so every agent reports the same number. Defined in ~/.claude/CLAUDE.md.
#
# Counts added + deleted lines of production + test code between the merge base
# of <base-ref> and the current working tree (committed + staged + unstaged +
# untracked), excluding:
#   - Generated files and lockfiles (default pathspec list; extend via
#     DIFF_BUDGET_EXTRA_EXCLUDE='path1:path2:...')
#   - Documentation under docs/ (design / PR / ADR documents are not
#     production or test code and do not consume the slice budget)
#   - Docstring-only lines (best-effort per language):
#       * Rust: lines starting with /// or //!
#       * TypeScript / JavaScript: JSDoc block lines (/**, */, leading *)
#       * Python: lines starting with """ or ''' (heuristic — multi-line
#         strings inside code may be over-counted as docstrings)
#       * Go: not detected (doc comments are indistinguishable from regular //)
#
# Usage:
#   diff-budget.sh [<base-ref>]
#
# If no base ref is given, "main" is used. Compared against the merge base of
# <base-ref> and HEAD, then extended with any uncommitted working-tree changes.
#
# Environment:
#   SOFT_BUDGET                  Soft line budget (default: 400)
#   HARD_BUDGET                  Hard line budget (default: 600)
#   DIFF_BUDGET_EXTRA_EXCLUDE    Colon-separated extra pathspec exclusions
#                                (e.g. 'src/generated/**:proto/generated/**')
#
# Output (stdout, one tab-separated key/value pair per line):
#   base_ref            <ref>
#   merge_base          <sha>
#   total_raw           <N>        # all added+deleted before any exclusion
#   generated_excluded  <N>        # lines removed by pathspec filter
#   docstring_excluded  <N>        # lines removed by language docstring filter
#   counted             <N>        # the budget-relevant number
#   soft_budget         <N>
#   hard_budget         <N>
#   verdict             within | soft_exceeded | hard_exceeded
#
# Exit codes:
#   0   counted <= SOFT_BUDGET
#   1   SOFT_BUDGET < counted <= HARD_BUDGET
#   2   counted > HARD_BUDGET
#   3   error (not a git repo / base ref missing / etc.)

set -euo pipefail

BASE_REF="${1:-main}"
SOFT_BUDGET="${SOFT_BUDGET:-400}"
HARD_BUDGET="${HARD_BUDGET:-600}"

EXCLUDE_PATHSPEC=(
  ':!docs/**'
  ':!**/Cargo.lock'
  ':!**/package-lock.json'
  ':!**/pnpm-lock.yaml'
  ':!**/yarn.lock'
  ':!**/poetry.lock'
  ':!**/uv.lock'
  ':!**/Gemfile.lock'
  ':!**/go.sum'
  ':!**/composer.lock'
  ':!**/target/**'
  ':!**/node_modules/**'
  ':!**/dist/**'
  ':!**/build/**'
  ':!**/.venv/**'
  ':!**/venv/**'
  ':!**/*.generated.*'
  ':!**/*.pb.go'
  ':!**/*_pb2.py'
  ':!**/*_pb2_grpc.py'
)

if [ -n "${DIFF_BUDGET_EXTRA_EXCLUDE:-}" ]; then
  IFS=':' read -ra extras <<< "$DIFF_BUDGET_EXTRA_EXCLUDE"
  for p in "${extras[@]}"; do
    [ -n "$p" ] && EXCLUDE_PATHSPEC+=(":!$p")
  done
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: not inside a git repository" >&2
  exit 3
fi

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "error: base ref not found: $BASE_REF" >&2
  exit 3
fi

MERGE_BASE=$(git merge-base "$BASE_REF" HEAD 2>/dev/null || true)
if [ -z "$MERGE_BASE" ]; then
  echo "error: could not determine merge base between $BASE_REF and HEAD" >&2
  exit 3
fi

# ---------------------------------------------------------------------------
# Tracked changes (committed + staged + unstaged). `git diff <commit>` sees
# these without requiring `git add`, but untracked files are invisible to it —
# they are handled in the second block below.
# ---------------------------------------------------------------------------

tracked_total_raw=$(
  git diff --numstat "$MERGE_BASE" \
    | awk '{added+=$1; deleted+=$2} END {print added+deleted+0}'
)

tracked_total_filtered=$(
  git diff --numstat "$MERGE_BASE" -- "${EXCLUDE_PATHSPEC[@]}" \
    | awk '{added+=$1; deleted+=$2} END {print added+deleted+0}'
)

tracked_docstring_excluded=$(
  git diff "$MERGE_BASE" -- "${EXCLUDE_PATHSPEC[@]}" \
    | awk '
        /^diff --git / {
          file = $NF
          sub(/^b\//, "", file)
          next
        }
        /^(\+\+\+|---)/ { next }
        /^[+-]/ {
          line = substr($0, 2)
          if (file ~ /\.rs$/ && line ~ /^[[:space:]]*(\/\/\/|\/\/!)/) {
            count++; next
          }
          if (file ~ /\.(ts|tsx|js|jsx|mjs|cjs)$/ &&
              line ~ /^[[:space:]]*(\/\*\*|\*\/|\*([[:space:]]|$))/) {
            count++; next
          }
          if (file ~ /\.py$/ && line ~ /^[[:space:]]*("""|'\''\'\''\'\'')/) {
            count++; next
          }
        }
        END { print count+0 }
      '
)

# ---------------------------------------------------------------------------
# Untracked changes (newly created files not yet `git add`ed). Count the
# entire file contents as "added" lines — this mirrors how they will be
# counted once staged.
# ---------------------------------------------------------------------------

count_file_docstrings() {
  local f="$1"
  case "$f" in
    *.rs)
      awk '/^[[:space:]]*(\/\/\/|\/\/!)/ { c++ } END { print c+0 }' "$f"
      ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
      awk '/^[[:space:]]*(\/\*\*|\*\/|\*([[:space:]]|$))/ { c++ } END { print c+0 }' "$f"
      ;;
    *.py)
      awk '/^[[:space:]]*("""|'\''\'\''\'\'')/ { c++ } END { print c+0 }' "$f"
      ;;
    *)
      echo 0
      ;;
  esac
}

untracked_total_raw=0
while IFS= read -r -d '' f; do
  [ -z "$f" ] && continue
  [ ! -f "$f" ] && continue
  untracked_total_raw=$((untracked_total_raw + $(wc -l < "$f")))
done < <(git ls-files --others --exclude-standard -z)

untracked_total_filtered=0
untracked_docstring_excluded=0
while IFS= read -r -d '' f; do
  [ -z "$f" ] && continue
  [ ! -f "$f" ] && continue
  untracked_total_filtered=$((untracked_total_filtered + $(wc -l < "$f")))
  untracked_docstring_excluded=$((untracked_docstring_excluded + $(count_file_docstrings "$f")))
done < <(git ls-files --others --exclude-standard -z -- "${EXCLUDE_PATHSPEC[@]}")

# ---------------------------------------------------------------------------
# Combine tracked + untracked.
# ---------------------------------------------------------------------------

total_raw=$((tracked_total_raw + untracked_total_raw))
total_filtered=$((tracked_total_filtered + untracked_total_filtered))
generated_excluded=$((total_raw - total_filtered))
docstring_excluded=$((tracked_docstring_excluded + untracked_docstring_excluded))

counted=$((total_filtered - docstring_excluded))
if [ "$counted" -lt 0 ]; then
  counted=0
fi

verdict="within"
exit_code=0
if [ "$counted" -gt "$HARD_BUDGET" ]; then
  verdict="hard_exceeded"
  exit_code=2
elif [ "$counted" -gt "$SOFT_BUDGET" ]; then
  verdict="soft_exceeded"
  exit_code=1
fi

printf 'base_ref\t%s\n' "$BASE_REF"
printf 'merge_base\t%s\n' "$MERGE_BASE"
printf 'total_raw\t%d\n' "$total_raw"
printf 'generated_excluded\t%d\n' "$generated_excluded"
printf 'docstring_excluded\t%d\n' "$docstring_excluded"
printf 'counted\t%d\n' "$counted"
printf 'soft_budget\t%d\n' "$SOFT_BUDGET"
printf 'hard_budget\t%d\n' "$HARD_BUDGET"
printf 'verdict\t%s\n' "$verdict"

exit "$exit_code"
