#!/bin/bash
# Pulls the latest commit and stamps __VERSION__ in index.html with the
# current short SHA so every deploy gets fresh asset URLs (cache busting).
set -euo pipefail

cd "$(dirname "$0")"

# Undo any prior in-place substitution so git pull can fast-forward cleanly.
git checkout -- index.html 2>/dev/null || true

git pull --ff-only

SHA=$(git rev-parse --short HEAD)
sed -i "s/__VERSION__/$SHA/g" index.html

echo "Deployed $SHA"
