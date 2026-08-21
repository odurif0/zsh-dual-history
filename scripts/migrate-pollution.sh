#!/bin/sh
# migrate-pollution.sh — move AI instructions out of the main history file.
#
# Historically, ": ..." commands (AI instructions) leaked into ~/.zsh_history
# (notably via Forge's `print -s`, which bypasses the zshaddhistory hook).
# This script rebuilds every multi-line entry, moves instructions that are in
# EXTENDED_HISTORY format (": <ts>:<dur>;:<cmd>") to the AI history file, and
# rewrites the main file without them. Both files are backed up first.
#
# Usage: scripts/migrate-pollution.sh [histfile] [ai_file]
#
# Run it with no other interactive zsh sessions open if possible: a running
# shell keeps its in-memory history and appends it back on exit, which can
# re-introduce old pollution. Re-running the script is safe (idempotent).

HIST="${1:-${HISTFILE:-$HOME/.zsh_history}}"
AI="${2:-${DUAL_HISTORY_AI_FILE:-$HOME/.zsh_ai_history}}"

[ -f "$HIST" ] || { echo "no history file: $HIST" >&2; exit 1; }
[ -d "$(dirname "$AI")" ] || mkdir -p "$(dirname "$AI")" || exit 1
[ -f "$AI" ] || { (umask 077 && : > "$AI") || exit 1; }

TS="$(date +%Y%m%d-%H%M%S)"
cp -p "$HIST" "$HIST.bak-dualhistory-$TS" || exit 1
cp -p "$AI" "$AI.bak-dualhistory-$TS" || exit 1

TMP_HIST="$(mktemp "${TMPDIR:-/tmp}/dh-main.XXXXXX")" || exit 1
TMP_AI="$(mktemp "${TMPDIR:-/tmp}/dh-ai.XXXXXX")" || exit 1

awk -v aiout="$TMP_AI" '
  # Re-emit multi-line entries with zsh backslash-continuation: a raw
  # newline would orphan continuation lines, which zsh later re-absorbs
  # as separate re-stamped events (mass-timestamp pollution).
  function flush_entry(  out) {
    if (buf ~ /^: [0-9]+:[0-9]+;[ \t]*$/) return  # empty junk entries
    out = buf
    gsub(/\n/, "\\\n", out)
    if (buf ~ /^: [0-9]+:[0-9]+;:/) print out >> aiout
    else print out
  }
  {
    if (pend) { buf = buf "\n" $0 } else { buf = $0 }
    pend = 0
    if (buf ~ /\\$/) { sub(/\\$/, "", buf); pend = 1; next }
    flush_entry()
  }
  END { if (pend) flush_entry() }
' "$HIST" > "$TMP_HIST" || { rm -f "$TMP_HIST" "$TMP_AI"; exit 1; }

# Count ENTRIES, not lines — multi-line entries span several physical lines
# (internal newlines are backslash-escaped), so NR would over-count.
moved=$(awk '{ if ($0 !~ /\\$/) n++ } END { print n+0 }' "$TMP_AI")
kept=$(awk '{ if ($0 !~ /\\$/) n++ } END { print n+0 }' "$TMP_HIST")

# In-place writes keep inode and permissions of the original files
cat "$TMP_HIST" >| "$HIST" && cat "$TMP_AI" >> "$AI"
rm -f "$TMP_HIST" "$TMP_AI"

echo "moved $moved AI instruction(s) to $AI"
echo "kept  $kept human command(s) in $HIST"
echo "backups: $HIST.bak-dualhistory-$TS, $AI.bak-dualhistory-$TS"
