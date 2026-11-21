#!/bin/bash
# Render the plg for one version.
# Usage: build-plugin.sh <version, e.g. 2026.11.21> <output dir>
set -euo pipefail

PLUGIN_NAME="it87-driver"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$1"
OUT_DIR="$(mkdir -p "$2" && cd "$2" && pwd)"

sed -e "s/@VERSION@/$VERSION/" "$REPO_DIR/$PLUGIN_NAME.plg" > "$OUT_DIR/$PLUGIN_NAME.plg"

# release notes: CHANGES entry of this version
awk -v v="###$VERSION" '$0==v{f=1;next} /^###/{f=0} f' "$REPO_DIR/$PLUGIN_NAME.plg" | sed '/^$/d' > "$OUT_DIR/notes.md"
ls -l "$OUT_DIR"
