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

This includes instructions that never reach the zsh parser at all: when Forge's
`forge-accept-line` widget records a `:` instruction via `print -s` (bypassing
both hooks), the plugin intercepts that exact call and reroutes it to the AI
file.

Your shell history stays 100% clean — `history`, `!!`, completions, everything —
while AI instructions are preserved in a separate file you can still search
and replay. With fzf, `Ctrl+R` becomes a single interface over **both**
histories (see [Usage](#usage)).

## Installation

**Requirements:** zsh 5.0+. The fzf integration requires fzf 0.52.0+; the
plugin works without fzf (everything except the smart `Ctrl+R`).

### With your AI coding agent (recommended)

Just paste this to any coding agent:

```
Install the zsh-dual-history Oh My Zsh plugin from github.com/odurif0/zsh-dual-history
```

The agent will clone the repo into `$ZSH_CUSTOM/plugins/`, add
`zsh-dual-history` to the plugins array in your `~/.zshrc`, and reload your
shell.

### Manual (Oh My Zsh)

```bash
git clone https://github.com/odurif0/zsh-dual-history.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-dual-history
```

Then in `~/.zshrc`:

```zsh
plugins=(... zsh-dual-history)
```

### Manual (without Oh My Zsh)

```bash
git clone https://github.com/odurif0/zsh-dual-history.git ~/.zsh-dual-history
echo 'source ~/.zsh-dual-history/zsh-dual-history.plugin.zsh' >> ~/.zshrc
```

## Usage

Open `Ctrl+R` and switch views on the fly — the fzf header always shows the
active view:

| Shortcut  | Action                                       |
|-----------|----------------------------------------------|
| `Ctrl+R`  | Open fzf with **all** history (human + AI)   |
| `Tab`     | Cycle through: All → Human → AI → All        |
| `Alt+H`   | Switch to human commands only                |
| `Alt+I`   | Switch to AI instructions only               |
| `Alt+A`   | Switch back to all history                   |

## What you see

| Tool | What you see |
|------|-------------|
| `history` / `fc -l` | Human commands only |
| `!!` / `!$` (bang expansion) | Human commands only |
| History-based completion | Human commands only |
| `cat ~/.zsh_history` | Human commands only |
| `cat ~/.zsh_ai_history` | AI instructions only |

`~/.zsh_history` only gets fully clean once existing leaked instructions are
moved out — see `scripts/migrate-pollution.sh` in
[How it works](#how-it-works).

## How it works

```
Command typed → zshaddhistory hook → starts with ":"?
                                      ├─ Yes → ~/.zsh_ai_history
                                      └─ No  → ~/.zsh_history

Forge instruction → forge-accept-line widget → print -s intercepted
                                      └─ → ~/.zsh_ai_history (never the memory)
```

The hooks run before zsh writes anything to disk — a single `if` on the
command prefix. A `preexec` hook writes the AI file for commands that go
through the parser, and the wrapper around `forge-accept-line` shadows the
`print` builtin only for the duration of the widget call, intercepting exactly
the `print -s` that adds the instruction to history; every other `print`
invocation passes through.

If your `~/.zsh_history` already contains leaked instructions, run
`scripts/migrate-pollution.sh` once to move them to the AI file (both files
are backed up first).

### fzf integration

The `Ctrl+R` widget is replaced with a custom fzf launcher that opens with
**all** history: human + AI merged and interleaved chronologically,
duplicates collapsed. Tab and Alt keys use fzf's `reload` and `transform`
actions to switch data sources without closing fzf. A snapshot of the
shell's in-memory history is taken at widget open, so the current session's
commands appear in every view even without
`share_history`/`inc_append_history`. `FZF_CTRL_R_OPTS` is honored like in
the upstream fzf widget.

## Configuration

| Variable                | Default               | Description                              |
|-------------------------|-----------------------|------------------------------------------|
| `DUAL_HISTORY_AI_FILE`  | `~/.zsh_ai_history`   | Path to AI history file                  |
| `DUAL_HISTORY_AI_SAVEHIST` | `10000`            | Max AI entries kept (pruned at load), `0` disables |

Set **before** the plugin is sourced:

```zsh
export DUAL_HISTORY_AI_FILE="$HOME/sync/ai-instructions.zsh"
```

## Limitations

- **Prefix routing**: any command starting with `:` is treated as an AI
  instruction — including human idioms like `: > file` (truncate). Use
  `true > file` or `> file` instead.
- **Up-arrow recall**: instructions are deliberately kept out of the shell's
  in-memory history, so `↑` no longer recalls them. Replay them from the
  `Ctrl+R` AI view instead.
- **Chronological merge** of both histories requires GNU sort (`sort -z`).
  Without it the views fall back to file order (still deduplicated).
- A long-running shell that predates the plugin can re-append old pollution
  to `~/.zsh_history` when it exits; re-run `scripts/migrate-pollution.sh`
  after closing those sessions.

## License

MIT
