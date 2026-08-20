#!/bin/sh
# Both histories merged and interleaved chronologically (by timestamp),
# duplicates collapsed (newest occurrence kept).
DIR="$(dirname "$0")"
TAB="$(printf '\t')"
if sort -z </dev/null >/dev/null 2>&1; then
  { "$DIR/stream.sh" human; "$DIR/stream.sh" ai; } \
    | sort -z -s -t "$TAB" -k1,1n | awk -f "$DIR/finish.awk"
else
  { "$DIR/stream.sh" human; "$DIR/stream.sh" ai; } | awk -f "$DIR/finish.awk"
fi
