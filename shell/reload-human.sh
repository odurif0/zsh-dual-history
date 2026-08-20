#!/bin/sh
# Human commands only: HISTFILE merged with the current-session snapshot,
# sorted chronologically, duplicates collapsed (newest occurrence kept).
DIR="$(dirname "$0")"
TAB="$(printf '\t')"
if sort -z </dev/null >/dev/null 2>&1; then   # GNU sort: chronological merge
  "$DIR/stream.sh" human | sort -z -s -t "$TAB" -k1,1n | awk -f "$DIR/finish.awk"
else                                          # fallback: file order
  "$DIR/stream.sh" human | awk -f "$DIR/finish.awk"
fi
