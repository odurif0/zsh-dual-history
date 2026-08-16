# zsh-dual-history — Separate human commands from AI instructions in zsh history
#
# Core (always active, no dependencies):
#   preexec hook writes ": " commands to ~/.zsh_ai_history
#   zshaddhistory hook prevents them from reaching the main history file
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
#   DUAL_HISTORY_AI_FILE  — path to AI history file (default: ~/.zsh_ai_history)
#
# License: MIT

(( ${+_DUAL_HISTORY_LOADED} )) && return 0
_DUAL_HISTORY_LOADED=1

: ${DUAL_HISTORY_AI_FILE:="$HOME/.zsh_ai_history"}
# Exported so the fzf reload scripts (children of fzf, not of this shell) see it
export DUAL_HISTORY_AI_FILE

# ---- Route ": " commands to AI history, not main history ----

# preexec fires reliably for every single command — this is the primary writer.
# Entry format mirrors zsh EXTENDED_HISTORY (": <ts>:<dur>;<cmd>"), with
# embedded newlines escaped as "<backslash><newline>" like zsh does.
_dual_history_preexec() {
  if [[ $1 == :* ]]; then
    local cmd=${1//$'\n'/'\'$'\n'}
    print -r -- ": ${EPOCHSECONDS:-$(date +%s)}:0;$cmd" >> "$DUAL_HISTORY_AI_FILE"
  fi
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

zmodload zsh/datetime 2>/dev/null  # $EPOCHSECONDS, avoids forking date(1)

# ---- Helper scripts for fzf reload (fzf runs reload via /bin/sh) ----
_DH_PLUGIN_DIR="${0:A:h}"
_DH_RELOAD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-dual-history"

if [[ -d "$_DH_PLUGIN_DIR/shell" ]]; then
  mkdir -p "$_DH_RELOAD_DIR"
  cp "$_DH_PLUGIN_DIR/shell"/* "$_DH_RELOAD_DIR/"
fi
chmod +x "$_DH_RELOAD_DIR"/reload-{ai,human,all,cycle,set}.sh 2>/dev/null

# Purge orphaned tab-cycle state files (their fzf process is gone)
for _dh_f in /tmp/fzf-dual-history-*(-.N); do
  kill -0 "${${_dh_f:t}#fzf-dual-history-}" 2>/dev/null || rm -f -- "$_dh_f"
done
unset _dh_f

# ---- Tab-cycling Ctrl+R widget ----
_dual_history_patch_ctrl_r() {
  (( ${+functions[fzf-history-widget]} )) || return 0
  (( ${+functions[_dual_history_smart_widget]} )) && return 0
  # Alt keys reload these scripts; without them the views would silently break
  [[ -x "$_DH_RELOAD_DIR/reload-all.sh" ]] || return 0

  _dual_history_smart_widget() {
    setopt localoptions pipefail no_aliases 2>/dev/null
    local selected

    # HISTFILE is usually NOT exported: pass it through to fzf so its reload
    # children read the same file the hooks write to, even when customized.
    selected="$(HISTFILE="${HISTFILE:-$HOME/.zsh_history}" \
      FZF_DEFAULT_OPTS="$(__fzf_defaults "" "-n2..,.. --scheme=history --highlight-line" 2>/dev/null)" \
      fzf --height ${FZF_TMUX_HEIGHT:-40%} --tac --read0 \
          --header="All history   |   Tab:cycle   Alt+H:Human   Alt+I:AI   Alt+A:All" \
          ${LBUFFER:+--query="${(qqq)LBUFFER}"} \
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
