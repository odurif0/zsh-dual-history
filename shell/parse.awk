# parse.awk — rebuild multi-line history entries, emit "ts<TAB>cmd<NUL>".
# Usage: awk -v mode=human|ai -f parse.awk FILE
#   - zsh escapes embedded newlines as a trailing backslash
#   - EXTENDED_HISTORY prefix ": <ts>:<dur>;" carries the timestamp
function emit(ts, cmd) {
  if (cmd ~ /^[ \t]*$/) return                    # junk/empty entries
  if (mode == "human" && cmd ~ /^:/) return
  if (mode == "ai" && cmd !~ /^:/) return
  printf "%s\t%s%c", ts, cmd, 0
}
function strip_prefix(s,   ts) {
  ts = 0
  if (s ~ /^: [0-9]+:[0-9]+;/) {
    ts = s; sub(/^: /, "", ts); sub(/:.*/, "", ts)
    sub(/^: [0-9]+:[0-9]+;/, "", s)
  } else {
    sub(/^: *[0-9]*:[0-9]*;/, "", s)
  }
  emit(ts, s)
}
{
  if (pend) { buf = buf "\n" $0 } else { buf = $0 }
  pend = 0
  if (buf ~ /\\$/) { sub(/\\$/, "", buf); pend = 1; next }
  strip_prefix(buf)
}
END {
  if (pend) strip_prefix(buf)
}
