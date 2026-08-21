# zsh-dual-history — Separate human commands from AI instructions in zsh history
#
# Core (always active, no dependencies):
#   preexec hook writes ": " commands to ~/.zsh_ai_history
#   zshaddhistory hook prevents them from reaching the main history file
#   forge-accept-line wrapper catches instructions routed around the parser
# Requires fzf 0.52.0+ for the Ctrl+R widget integration.
# Oh My Zsh recommended but optional.
#
# Installation (Oh My Zsh):
#   1. Copy this directory to: $ZSH_CUSTOM/plugins/zsh-dual-history/
#   2. Add "zsh-dual-history" to plugins=(...) in ~/.zshrc
#
# Installation (standalone):
#   source /path/to/zsh-dual-history.plugin.zsh
#
# Configuration (optional, set before sourcing):
#   DUAL_HISTORY_AI_FILE      — path to AI history file (default: ~/.zsh_ai_history)
#   DUAL_HISTORY_AI_SAVEHIST  — max AI entries kept, 0 disables (default: 10000)
#
# License: MIT

(( ${+_DUAL_HISTORY_LOADED} )) && return 0
_DUAL_HISTORY_LOADED=1

: ${DUAL_HISTORY_AI_FILE:="$HOME/.zsh_ai_history"}
: ${DUAL_HISTORY_AI_SAVEHIST:=10000}
# Exported so the fzf reload scripts (children of fzf, not of this shell) see it
export DUAL_HISTORY_AI_FILE

zmodload zsh/datetime 2>/dev/null  # $EPOCHSECONDS, avoids forking date(1)

# ---- Writer (single source of truth for the AI history format) ----
# Entry format mirrors zsh EXTENDED_HISTORY (": <ts>:0;<cmd>"), with embedded
# newlines escaped as "<backslash><newline>" like zsh does.
_dual_history_write_ai() {
  local cmd=${1//$'\n'/'\'$'\n'}
  builtin print -r -- ": ${EPOCHSECONDS:-$(date +%s)}:0;$cmd" >> "$DUAL_HISTORY_AI_FILE"
}

# ---- Route ": " commands to AI history, not main history ----

# preexec fires reliably for every single command — this is the primary writer
_dual_history_preexec() {
  if [[ $1 == :* ]]; then
    _dual_history_write_ai "$1"
  fi
  return 0
}

# zshaddhistory prevents ": " commands from reaching the main history file
_dual_history_zshaddhistory() {
  if [[ $1 == :* ]]; then
    return 1
  fi
  return 0
}

autoload -U add-zsh-hook
add-zsh-hook preexec _dual_history_preexec
add-zsh-hook zshaddhistory _dual_history_zshaddhistory

# ---- Intercept Forge's accept-line widget ----
# Forge rebinds Enter on `: ...` buffers and records them itself via
# `print -s`, which bypasses BOTH hooks (no accept-line -> no preexec, and
# print -s never consults zshaddhistory). We wrap Forge's widget: while the
# original runs, a scoped `print` function intercepts exactly that `print -s`
# call, routes the entry to the AI file, and suppresses the insertion into
# the main history. Every other print invocation passes through untouched.
_dual_history_wrap_forge_accept() {
  (( ${+functions[forge-accept-line]} )) || return 0
  [[ "$functions[forge-accept-line]" == *'_dual_history_forge_orig'* ]] && return 0
  functions[_dual_history_forge_orig]="$functions[forge-accept-line]"
  forge-accept-line() {
    local _dh_print_saved="${functions[print]}"
    print() {
      if [[ "$1" == -s && $# -ge 2 ]]; then
        _dual_history_write_ai "${@[-1]}"
        return 0
      fi
      builtin print "$@"
    }
    # always: restore `print` even if the original widget errors or is
    # interrupted — a leaked global print() shadow would break the shell.
    {
      _dual_history_forge_orig "$@"
    } always {
      (( ${+functions[print]} )) && unfunction print
      [[ -n "$_dh_print_saved" ]] && functions[print]="$_dh_print_saved"
    }
  }
}

# ---- Helper scripts for fzf reload (fzf runs reload via /bin/sh) ----
_DH_PLUGIN_DIR="${0:A:h}"
_DH_RELOAD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-dual-history"
# State dir: per-UID, XDG_RUNTIME_DIR (0700) when available — /tmp files
# writable via symlink by other local users were a hardening hole.
_DH_STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/zsh-dual-history-$UID"

(umask 077 && mkdir -p "$_DH_RELOAD_DIR" "$_DH_STATE_DIR") 2>/dev/null
# downgrade dirs created by older versions with a lax umask
chmod 700 "$_DH_STATE_DIR" 2>/dev/null
if [[ -d "$_DH_PLUGIN_DIR/shell" ]]; then
  cp "$_DH_PLUGIN_DIR/shell"/* "$_DH_RELOAD_DIR/"
fi
chmod +x "$_DH_RELOAD_DIR"/*.sh 2>/dev/null

# Purge state files whose owner process is gone (cycle-<fzf-pid>,
# session-<shell-pid>), plus legacy /tmp files from earlier versions.
for _dh_f in "$_DH_STATE_DIR"/cycle-*(-.N) "$_DH_STATE_DIR"/session-*(-.N); do
  _dh_p="${_dh_f:t}"; _dh_p="${_dh_p#cycle-}"; _dh_p="${_dh_p#session-}"
  kill -0 "$_dh_p" 2>/dev/null || rm -f -- "$_dh_f"
done
rm -f -- /tmp/fzf-dual-history-*(N)
unset _dh_f _dh_p

# AI history file: private by default (it can contain sensitive instructions)
if [[ ! -f "$DUAL_HISTORY_AI_FILE" ]]; then
  (umask 077 && : > "$DUAL_HISTORY_AI_FILE") 2>/dev/null
fi

# ---- Prune the AI history (SAVEHIST-equivalent, opt-out) ----
if [[ "$DUAL_HISTORY_AI_SAVEHIST" != "0" && -s "$DUAL_HISTORY_AI_FILE" ]]; then
  integer _dh_max _dh_lines
  _dh_max="$DUAL_HISTORY_AI_SAVEHIST"
  _dh_lines="$(wc -l < "$DUAL_HISTORY_AI_FILE")"
  if (( _dh_lines > _dh_max )); then
    awk -v max="$_dh_max" '
      { line[NR] = $0 }
      END {
        n = 0; pend = 0; buf = ""
        for (i = 1; i <= NR; i++) {
          if (pend) { buf = buf "\n" line[i] } else { buf = line[i] }
          pend = 0
          if (buf ~ /\\$/) { sub(/\\$/, "", buf); pend = 1; continue }
          n++; ent[n] = buf
        }
        if (pend) { n++; ent[n] = buf }
        for (i = n - max + 1 > 1 ? n - max + 1 : 1; i <= n; i++) print ent[i]
      }' "$DUAL_HISTORY_AI_FILE" >| "${DUAL_HISTORY_AI_FILE}.dhprune" 2>/dev/null \
      && cat "${DUAL_HISTORY_AI_FILE}.dhprune" >| "$DUAL_HISTORY_AI_FILE"
    rm -f "${DUAL_HISTORY_AI_FILE}.dhprune"
  fi
fi

# ---- Tab-cycling Ctrl+R widget ----
_dual_history_patch_ctrl_r() {
  _dual_history_wrap_forge_accept

  (( ${+functions[fzf-history-widget]} )) || return 0
  (( ${+functions[_dual_history_smart_widget]} )) && return 0
  # Alt keys reload these scripts; without them the views would silently break
  [[ -x "$_DH_RELOAD_DIR/reload-all.sh" ]] || return 0

  # Snapshot in-memory history for the reload scripts — they run as children
  # of fzf and cannot see this shell's history list. Taken at widget open,
  # so every view (initial + reloads) includes the current session even
  # without share_history/inc_append_history.
  # NOTE: the $historytime assoc is NOT reliably populated (empty even with
  # extended_history set) — stamping entries "now" would flood the top of
  # the view with the whole in-memory history. Dump via `fc -A` instead:
  # it writes native EXTENDED_HISTORY format with REAL timestamps, parsed
  # by the same parse.awk as the on-disk history.
  _dual_history_dump_session() {
    export _DUAL_HISTORY_SESSION=""
    [[ -d "$_DH_STATE_DIR" ]] || return 0
    local _sf="$_DH_STATE_DIR/session-$$"
    setopt localoptions extended_history
    (umask 077 && : >| "$_sf") 2>/dev/null || return 0
    builtin fc -A "$_sf" 2>/dev/null
    export _DUAL_HISTORY_SESSION="$_sf"
  }

  _dual_history_smart_widget() {
    setopt localoptions pipefail no_aliases 2>/dev/null
    local selected _dh_fzf_defaults=""
    local -a _dh_extra
    [[ -n "${FZF_CTRL_R_OPTS:-}" ]] && _dh_extra=(${(z)FZF_CTRL_R_OPTS})

    # If __fzf_defaults is undefined (plugin sourced without fzf's completion),
    # leave the user's own FZF_DEFAULT_OPTS untouched instead of clobbering it.
    if (( ${+functions[__fzf_defaults]} )); then
      _dh_fzf_defaults="$(__fzf_defaults "" "-n2..,.. --scheme=history --bind=ctrl-r:toggle-sort --highlight-line" 2>/dev/null)"
    fi

    _dual_history_dump_session

    # HISTFILE is usually NOT exported: pass it through to fzf so its reload
    # children read the same file the hooks write to, even when customized.
    selected="$(HISTFILE="${HISTFILE:-$HOME/.zsh_history}" \
      FZF_DEFAULT_OPTS="${_dh_fzf_defaults:-$FZF_DEFAULT_OPTS}" \
      fzf --height ${FZF_TMUX_HEIGHT:-40%} --tac --read0 \
          --header="All history   |   Tab:cycle   Alt+H:Human   Alt+I:AI   Alt+A:All" \
          ${LBUFFER:+--query="$LBUFFER"} \
          ${_dh_extra[@]} \
          --bind="alt-a:transform($_DH_RELOAD_DIR/reload-set.sh all $_DH_RELOAD_DIR)" \
          --bind="tab:transform($_DH_RELOAD_DIR/reload-cycle.sh $_DH_RELOAD_DIR)" \
          --bind="alt-h:transform($_DH_RELOAD_DIR/reload-set.sh human $_DH_RELOAD_DIR)" \
          --bind="alt-i:transform($_DH_RELOAD_DIR/reload-set.sh ai $_DH_RELOAD_DIR)" \
      < <(HISTFILE="${HISTFILE:-$HOME/.zsh_history}" "$_DH_RELOAD_DIR"/reload-all.sh 2>/dev/null))"
    local ret=$?
    if [[ -n "$selected" ]]; then
      LBUFFER="$selected"
      CURSOR=${#LBUFFER}
    fi
    zle reset-prompt
    return $ret
  }

  zle -N _dual_history_smart_widget
  bindkey -M emacs '^R' _dual_history_smart_widget
  bindkey -M viins '^R' _dual_history_smart_widget
  bindkey -M vicmd '^R' _dual_history_smart_widget
}

autoload -U add-zsh-hook
add-zsh-hook precmd _dual_history_patch_ctrl_r
_dual_history_patch_ctrl_r
