#!/bin/sh
# Jump to an explicit view (used by Alt+H/I/A) and keep the Tab cycle in
# sync: state is stored per fzf PID ($PPID of this script).
_VIEW="$1"; _DIR="$2"
_STATE="/tmp/fzf-dual-history-${PPID}"
_HINTS="   |   Tab:cycle   Alt+H:Human   Alt+I:AI   Alt+A:All"
case "$_VIEW" in
  all)   echo 0 > "$_STATE"; printf 'reload(%s/reload-all.sh)+change-header(All history%s)' "$_DIR" "$_HINTS" ;;
  human) echo 1 > "$_STATE"; printf 'reload(%s/reload-human.sh)+change-header(Human commands%s)' "$_DIR" "$_HINTS" ;;
  ai)    echo 2 > "$_STATE"; printf 'reload(%s/reload-ai.sh)+change-header(AI instructions%s)' "$_DIR" "$_HINTS" ;;
esac
