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

# ---- Route ": " commands to AI history, not main history ----

# preexec fires reliably for every single command — this is the primary writer
_dual_history_preexec() {
  if [[ $1 == :* ]]; then
    print -r -- ": $(date +%s):0;$1" >> "$DUAL_HISTORY_AI_FILE"
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

# ---- Helper scripts for fzf reload (fzf runs reload via /bin/sh) ----
_DH_PLUGIN_DIR="${0:A:h}"
_DH_RELOAD_DIR="${XDG_CACHE_HOME:-$HOME}/.cache/zsh-dual-history"

if [[ -d "$_DH_PLUGIN_DIR/shell" ]]; then
  mkdir -p "$_DH_RELOAD_DIR"
  cp "$_DH_PLUGIN_DIR/shell"/* "$_DH_RELOAD_DIR/"
fi
chmod +x "$_DH_RELOAD_DIR"/reload-{ai,human,all,cycle}.sh 2>/dev/null

# ---- Tab-cycling Ctrl+R widget ----
_dual_history_patch_ctrl_r() {
  (( ${+functions[fzf-history-widget]} )) || return
  (( ${+functions[__fzf_history_widget_orig]} )) && return

  functions[__fzf_history_widget_orig]="${functions[fzf-history-widget]}"

  _dual_history_smart_widget() {
    setopt localoptions pipefail no_aliases 2>/dev/null
    local selected

    selected="$(FZF_DEFAULT_OPTS="$(__fzf_defaults "" "" "" 2>/dev/null)" \
      fzf --height ${FZF_TMUX_HEIGHT:-40%} --tac --scheme=history \
          --header="Tab:cycle   Alt+H:Human   Alt+I:AI   Alt+A:All" \
          ${LBUFFER:+--query="${(qqq)LBUFFER}"} \
          --bind="alt-a:reload($_DH_RELOAD_DIR/reload-all.sh)+change-header(All history)" \
          --bind="tab:transform($_DH_RELOAD_DIR/reload-cycle.sh $_DH_RELOAD_DIR)" \
          --bind="alt-h:reload($_DH_RELOAD_DIR/reload-human.sh)+change-header(Human commands)" \
          --bind="alt-i:reload($_DH_RELOAD_DIR/reload-ai.sh)+change-header(AI instructions)" \
      < <("$_DH_RELOAD_DIR"/reload-all.sh 2>/dev/null))"
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
