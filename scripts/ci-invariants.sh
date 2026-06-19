#!/bin/bash
# Repo-wide security-invariant scan for CI. Exits nonzero on any HARD violation.
# REVIEW items are printed but never fail the build.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/invariant-patterns.sh"
cd "$PROJECT_DIR"

hard=0; review=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # Strip the severity tag, then the project root — both patterns quoted so a
    # path containing glob metacharacters can't be misinterpreted by the # expansion.
    case "$line" in
      HARD:*)   rel=${line#"HARD:"};   printf '✗ %s\n' "${rel#"$PROJECT_DIR/"}" >&2; hard=$((hard+1)) ;;
      REVIEW:*) rel=${line#"REVIEW:"}; printf '• %s\n' "${rel#"$PROJECT_DIR/"}";     review=$((review+1)) ;;
    esac
  done < <(inv_check_file "$PROJECT_DIR/$f")
done < <(git ls-files '*.swift' '*.plist')

echo ""
echo "Security invariants: ${hard} HARD, ${review} REVIEW"
if [ "$hard" -gt 0 ]; then echo "FAILED — HARD violations must be fixed." >&2; exit 1; fi
exit 0
