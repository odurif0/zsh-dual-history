#!/bin/sh
# Emit the raw "ts<TAB>entry<NUL>" stream for a view (human|ai).
# Internal helper for the reload-*.sh scripts — not a fzf source itself.
DIR="$(dirname "$0")"
MODE="$1"
case "$MODE" in
  human)
    awk -v mode=human -f "$DIR/parse.awk" "${HISTFILE:-$HOME/.zsh_history}" 2>/dev/null
    # Current-session snapshot (in-memory history of the invoking shell),
    # written by the widget at open time. Dedup keeps the newest version.
    if [ -n "${_DUAL_HISTORY_SESSION:-}" ] && [ -r "$_DUAL_HISTORY_SESSION" ]; then
      cat "$_DUAL_HISTORY_SESSION"
    fi
    ;;
  ai)
    awk -v mode=ai -f "$DIR/parse.awk" "${DUAL_HISTORY_AI_FILE:-$HOME/.zsh_ai_history}" 2>/dev/null
    ;;
esac
