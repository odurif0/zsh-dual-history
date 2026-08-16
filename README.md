# zsh-dual-history

Separate human shell commands from AI instructions in zsh history.
Designed for Forge with Oh My Zsh — with first-class fzf integration.

## The problem

Forge (with Oh My Zsh) sends instructions to AI models by prefixing them with
`:` (a zsh no-op builtin). These instructions pollute your `Ctrl+R` and `history`
output, mixing with your day-to-day shell commands.

## The solution

**zsh-dual-history** intercepts every command before zsh writes it to disk and
routes it to the right history file:

- `:` commands (AI instructions) → `~/.zsh_ai_history`
- everything else (your commands) → `~/.zsh_history`

Your shell history stays 100% clean — `history`, `!!`, completions, everything —
while AI instructions are preserved in a separate file you can still search
and replay.

On top of that, the `Ctrl+R` widget becomes a smart fzf interface showing
**both** histories merged, with one-key toggles (`Tab`, `Alt+H`, `Alt+I`,
`Alt+A`) to switch between All / Human / AI views on the fly.

## Installation

### With your AI coding agent (recommended)

Just paste this to any coding agent:

```
Install the zsh-dual-history Oh My Zsh plugin from github.com/odurif1/zsh-dual-history
```

The agent will clone the repo, symlink it into `$ZSH_CUSTOM/plugins/`, add
`zsh-dual-history` to your `~/.zshrc` plugins array, and clean up
any inline patches.

### Manual (Oh My Zsh)

```bash
git clone https://github.com/odurif1/zsh-dual-history.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-dual-history
```

Then in `~/.zshrc`:

```zsh
plugins=(... zsh-dual-history)
```

### Manual (without Oh My Zsh)

```bash
git clone https://github.com/odurif1/zsh-dual-history.git ~/.zsh-dual-history
echo 'source ~/.zsh-dual-history/zsh-dual-history.plugin.zsh' >> ~/.zshrc
```

**Requirements:** zsh 5.0+
**fzf integration requires:** fzf 0.52.0+ (plugin still works without it)

## Usage

| Shortcut  | Action                                       |
|-----------|----------------------------------------------|
| `Ctrl+R`  | Open fzf with **all** history (human + AI)   |
| `Tab`     | Cycle through: All → Human → AI → All        |
| `Alt+H`   | Switch to human commands only                |
| `Alt+I`   | Switch to AI instructions only               |
| `Alt+A`   | Switch back to all history                   |
| `history` | Display human shell history only (clean)     |
| `cat ~/.zsh_ai_history` | View raw AI instruction history   |

The fzf header always shows the current active view.

## What it does

**Two layers, one plugin:**

### Layer 1 — Clean history (always active, no dependencies)

A `zshaddhistory` hook routes `:` commands to `~/.zsh_ai_history` and keeps
them out of `~/.zsh_history`. This means **every** history feature stays clean:

| Tool | What you see |
|------|-------------|
| `history` / `fc -l` | Human commands only |
| `!!` / `!$` (bang expansion) | Human commands only |
| Completion based on history | Human commands only |
| `cat ~/.zsh_history` | Human commands only |
| `cat ~/.zsh_ai_history` | AI instructions only |

### Layer 2 — fzf search (opt-in, requires fzf)

The `Ctrl+R` widget is replaced with a smart fzf interface that shows **all**
history by default, with one-key toggles to switch views on the fly.

## How it works

### Core (works everywhere, no dependencies)

```
Command typed → zshaddhistory hook → starts with ":"?
                                      ├─ Yes → ~/.zsh_ai_history
                                      └─ No  → ~/.zsh_history
```

The hook runs before zsh writes anything to disk. It's a single `if` statement
that checks the command prefix — nothing else touches your config.

### fzf integration (builds on top of the core)

The `Ctrl+R` widget is replaced with a custom fzf launcher that opens with
**all** history (human + AI merged) by default. Tab and Alt keys use fzf's
`reload` and `transform` actions to switch data sources dynamically without
closing and reopening fzf. Tab state is keyed on the fzf PID so multiple fzf
instances don't interfere.

## Configuration

| Variable               | Default               | Description                  |
|------------------------|-----------------------|------------------------------|
| `DUAL_HISTORY_AI_FILE` | `~/.zsh_ai_history`   | Path to AI history file      |

Set **before** the plugin is sourced:

```zsh
export DUAL_HISTORY_AI_FILE="$HOME/sync/ai-instructions.zsh"
```

## License

MIT
