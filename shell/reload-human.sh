#!/bin/sh
# Human commands only.
# Rebuild full (possibly multi-line) entries — zsh escapes embedded newlines
# as a trailing backslash — then strip the EXTENDED_HISTORY prefix
# (": <timestamp>:<duration>;") and drop leftover ":" commands.
# Entries are NUL-separated (fzf is started with --read0) so a multi-line
# command is a single selectable item.
awk '
  {
    if (pend) { buf = buf "\n" $0 } else { buf = $0 }
    pend = 0
    if (buf ~ /\\$/) { sub(/\\$/, "", buf); pend = 1; next }
    sub(/^: *[0-9]*:[0-9]*;/, "", buf)
    if (buf !~ /^:/) printf "%s%c", buf, 0
  }
  END {
    if (pend) {
      sub(/^: *[0-9]*:[0-9]*;/, "", buf)
      if (buf !~ /^:/) printf "%s%c", buf, 0
    }
  }
' "${HISTFILE:-$HOME/.zsh_history}" 2>/dev/null
