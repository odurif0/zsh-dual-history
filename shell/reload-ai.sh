#!/bin/sh
# AI instructions only.
# Rebuild full (possibly multi-line) entries — newlines are escaped as a
# trailing backslash in the file — then strip the EXTENDED_HISTORY prefix
# (": <timestamp>:<duration>;") so the view shows the bare instruction,
# ready to be replayed as-is. NUL-separated for fzf --read0.
awk '
  {
    if (pend) { buf = buf "\n" $0 } else { buf = $0 }
    pend = 0
    if (buf ~ /\\$/) { sub(/\\$/, "", buf); pend = 1; next }
    sub(/^: *[0-9]*:[0-9]*;/, "", buf)
    printf "%s%c", buf, 0
  }
  END {
    if (pend) {
      sub(/^: *[0-9]*:[0-9]*;/, "", buf)
      printf "%s%c", buf, 0
    }
  }
' "${DUAL_HISTORY_AI_FILE:-$HOME/.zsh_ai_history}" 2>/dev/null
