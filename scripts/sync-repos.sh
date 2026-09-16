#!/usr/bin/env bash
# Regenera la lista de repos del dropdown "Otros repos afectados" en tareas.yml
# a partir de los repos vivos de la organización.
#
#   bash scripts/sync-repos.sh          # reescribe el template
#   bash scripts/sync-repos.sh --check  # solo verifica, sale 1 si está desactualizado
set -euo pipefail

ORG="${ORG:-NorkutArg}"
TEMPLATE=".github/ISSUE_TEMPLATE/tareas.yml"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Repos que no son módulos y no tienen sentido como "repo afectado".
EXCLUDE='^(\.github)$'

repos="$(
  gh api "orgs/$ORG/repos" --paginate \
    --jq '.[] | select(.archived == false) | .name' |
  grep -Ev "$EXCLUDE" |
  LC_ALL=C sort
)"

[ -n "$repos" ] || { echo "error: la org $ORG no devolvió repos" >&2; exit 1; }

optsfile="$(mktemp)"
trap 'rm -f "$optsfile"' EXIT
printf '%s\n' "$repos" | sed 's/^/        - /' > "$optsfile"

new="$(
  awk -v optsfile="$optsfile" '
    /# BEGIN-REPOS/ { print; while ((getline line < optsfile) > 0) print line; skip = 1; next }
    /# END-REPOS/   { skip = 0 }
    !skip           { print }
  ' "$TEMPLATE"
)"

if [ "${1:-}" = --check ]; then
  if diff -q <(printf '%s\n' "$new") "$TEMPLATE" >/dev/null; then
    echo "$TEMPLATE está al día ($(printf '%s\n' "$repos" | wc -l | tr -d ' ') repos)"
  else
    echo "$TEMPLATE está desactualizado:" >&2
    diff <(printf '%s\n' "$new") "$TEMPLATE" >&2 || true
    exit 1
  fi
else
  printf '%s\n' "$new" > "$TEMPLATE"
  echo "$TEMPLATE actualizado ($(printf '%s\n' "$repos" | wc -l | tr -d ' ') repos)"
fi
