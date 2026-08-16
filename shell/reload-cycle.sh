#!/bin/sh
# Cycle the Ctrl+R view: All -> Human -> AI -> All.
# State is keyed on the fzf PID ($PPID of this script) so concurrent fzf
# instances don't interfere. Orphaned state files are purged by the plugin
# at shell startup.
_DIR="$1"
_STATE="/tmp/fzf-dual-history-${PPID}"
state=$(cat "$_STATE" 2>/dev/null || echo 0)
next=$(( (state + 1) % 3 ))
echo "$next" > "$_STATE"
_HINTS="   |   Tab:cycle   Alt+H:Human   Alt+I:AI   Alt+A:All"
case $next in
  0) printf 'reload(%s/reload-all.sh)+change-header(All history%s)' "$_DIR" "$_HINTS" ;;
  1) printf 'reload(%s/reload-human.sh)+change-header(Human commands%s)' "$_DIR" "$_HINTS" ;;
  2) printf 'reload(%s/reload-ai.sh)+change-header(AI instructions%s)' "$_DIR" "$_HINTS" ;;
esac
