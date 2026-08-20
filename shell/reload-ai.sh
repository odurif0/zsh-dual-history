#!/bin/sh
# AI instructions only, sorted chronologically, duplicates collapsed.
DIR="$(dirname "$0")"
TAB="$(printf '\t')"
if sort -z </dev/null >/dev/null 2>&1; then
  "$DIR/stream.sh" ai | sort -z -s -t "$TAB" -k1,1n | awk -f "$DIR/finish.awk"
else
  "$DIR/stream.sh" ai | awk -f "$DIR/finish.awk"
fi
