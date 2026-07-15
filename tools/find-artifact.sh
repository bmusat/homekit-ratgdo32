#!/usr/bin/env bash
# Finds the most recent non-expired build-check.yml artifact(s) on this fork.
#
# GitHub Actions artifacts are never committed to the repo - they're attached
# to whichever workflow run produced them, and build-check.yml's skip-if-
# unchanged logic means many recent runs produce none at all. That makes the
# Actions UI tedious to search by hand: you have to open runs one at a time
# to find one that actually built something. This queries the repo-wide
# artifacts API instead (which spans every run, not just one), so the lookup
# is a single query regardless of how many runs were skips.
#
# Usage:
#   ./tools/find-artifact.sh                        # list the latest of each artifact
#   ./tools/find-artifact.sh <pattern>               # filter names by pattern (e.g. branch name)
#   ./tools/find-artifact.sh <pattern> --download    # also download the single latest match
#
# Examples:
#   ./tools/find-artifact.sh
#   ./tools/find-artifact.sh lock-state-crosstalk
#   ./tools/find-artifact.sh lock-state-crosstalk-latest --download

set -euo pipefail

usage() {
  cat <<EOF
Usage:
  $0                        list the latest of each artifact
  $0 <pattern>               filter names by pattern (e.g. branch name)
  $0 <pattern> --download    also download the single latest match
  $0 -h | --help             show this help

Examples:
  $0
  $0 lock-state-crosstalk
  $0 lock-state-crosstalk-latest --download
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

REPO="bmusat/homekit-ratgdo32"
PATTERN="${1:-.}"
DOWNLOAD=false
[ "${2:-}" = "--download" ] && DOWNLOAD=true

MATCHES=$(gh api "repos/$REPO/actions/artifacts" | jq --arg p "$PATTERN" '
  [.artifacts[] | select(.name | test($p)) | select(.expired == false)]
  | group_by(.name)
  | map(sort_by(.created_at) | reverse | .[0])
  | sort_by(.created_at) | reverse
')

COUNT=$(echo "$MATCHES" | jq 'length')
if [ "$COUNT" -eq 0 ]; then
  echo "No non-expired artifacts found matching \"$PATTERN\"."
  exit 1
fi

{
  echo -e "NAME\tCREATED\tEXPIRES\tRUN"
  echo "$MATCHES" | jq -r '.[] | "\(.name)\t\(.created_at)\texpires \(.expires_at)\trun \(.workflow_run.id)"'
} | column -t -s $'\t'

if [ "$COUNT" -gt 1 ]; then
  if [ "$DOWNLOAD" = true ]; then
    echo
    echo "Multiple matches - narrow your pattern to download a specific one, e.g.:"
    echo "  $0 \"${PATTERN}-latest\" --download"
  fi
  exit 0
fi

NAME=$(echo "$MATCHES" | jq -r '.[0].name')
RUN_ID=$(echo "$MATCHES" | jq -r '.[0].workflow_run.id')

if [ "$DOWNLOAD" = true ]; then
  echo
  echo "Downloading $NAME from run $RUN_ID..."
  mkdir -p "$NAME"
  gh run download "$RUN_ID" --repo "$REPO" -n "$NAME" -D "$NAME"
  echo "Saved to ./$NAME/"
else
  echo
  echo "Add --download to fetch it directly: $0 \"$PATTERN\" --download"
fi
