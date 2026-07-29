#!/usr/bin/env bash
# One-command backup: commit all local work and push it to GitHub.
# Usage (from the repo root):  ./tools/backup.sh ["message"]
set -e
MSG="${1:-backup: work in progress $(date '+%Y-%m-%d %H:%M')}"
git add -A
git commit -m "$MSG" || echo "Nothing new to back up."
git push && echo "Backed up to GitHub."
