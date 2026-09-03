# mac-my-shell

Personal zsh + terminal setup: smart autosuggestions, fuzzy Tab-completion, fuzzy history
search, a custom `claude` CLI completion, `navi`'s cheat-sheet picker, and a themed WezTerm
config. Works on **macOS and Linux**. Everything installs under `$HOME` — no Homebrew, and
no `sudo` on macOS. On Linux, `sudo` is used for exactly one thing: installing the `zsh`
package itself (there's no sudo-free way to get a zsh binary onto the box) and switching
the login shell to it. The WezTerm tab/status-bar config is macOS-only (assumes a local GUI
terminal) and is skipped on Linux.

## Quick start

```bash
git clone git@github.com:veerapan-boo/mac-my-shell.git
cd mac-my-shell
./install.sh
```

Re-running `install.sh` is safe — every step is skipped if its target already exists.
If you already have a `~/.zshrc`, it's backed up to `~/.zshrc.bak.<timestamp>` before
being replaced.

On Linux, `navi` is installed from its prebuilt release binary. On macOS there's no
prebuilt binary, so the script installs a minimal, self-contained `rustup`/`cargo`
toolchain under `~/.cargo` and builds it from source — that step alone takes a few
minutes on a fresh machine.

## What you get

| Feature | How | Trigger |
|---|---|---|
| Ghost-text suggestions from history + completions | zsh-autosuggestions | as you type |
| Fuzzy, interactive Tab-completion menu (with preview for `cd`/`kill`) | fzf-tab | Tab |
| Fish-style history filtering | zsh-history-substring-search | ↑ / ↓ |
| Fuzzy history search / file finder / cd | fzf | Ctrl+R / Ctrl+T / Alt+C |
| Accept a full suggestion / one word | zsh-autosuggestions | Ctrl+Space / Ctrl+Right |
| Command syntax highlighting (valid = green, invalid = red) | zsh-syntax-highlighting | as you type |
| Popular full-command recipes (e.g. `git config --global user.name <name>`) | navi + denisidoro/cheats | Ctrl+G |
| `claude --<Tab>` shows every real flag and subcommand | generated `_claude` completion | Tab |
| Custom-colored WezTerm tabs + CPU/RAM/DISK/time in the status bar | `config/wezterm/wezterm.lua` | on launch |

## Regenerating the `claude` completion

The `claude` CLI has no completion of its own — `config/zsh/completions/generate-claude-completion.py`
parses `claude --help` (and each subcommand's `--help`) into a zsh `_arguments` spec.
After upgrading Claude Code, run:

```bash
claude-refresh-completion
```

(defined in `~/.zshrc`, installed by this repo) to pick up new or renamed flags.

## Layout

- `install.sh` — idempotent bootstrap script; the only thing you run.
- `config/zshrc` — copied to `~/.zshrc`.
- `config/zsh/completions/generate-claude-completion.py` — copied to `~/.zsh/completions/`.
- `config/wezterm/` — copied to `~/.config/wezterm/` (tab colors, retro tab bar, right-status
  CPU/RAM/DISK/time script).

Plugins, `fzf`, `navi`, and the cheat-sheet repo are **not** vendored here — `install.sh`
clones/builds them fresh from upstream each time, so this repo stays small and always
picks up current upstream versions.

## Design notes

- No Homebrew: everything lives under `$HOME` (`~/.zsh`, `~/.fzf`, `~/.cargo`,
  `~/.local/share/navi`, `~/.local/bin`), so this works identically on a locked-down
  non-admin macOS account. On Linux, `zsh` itself comes from `apt` (`sudo` required) since
  there's no `$HOME`-only way to get the binary; everything downstream of that is the same
  sudo-free install as macOS.
- `compinit -u` in `~/.zshrc` skips the insecure-directory prompt for zsh completion
  dirs owned by another account (e.g. an admin user on a shared Mac, or root-owned system
  completion dirs on Linux) — otherwise `compaudit` hangs waiting for interactive y/n
  input during shell startup.
- `~/.zshrc` picks the right `ls` color flag at load time (`-G` for BSD `ls` on macOS,
  `--color=always` for GNU `ls` on Linux) so the same file works unmodified on both.
- fzf's own `completion.zsh` is intentionally not sourced — it rebinds Tab and silently
  overrides fzf-tab's Tab binding. Only `key-bindings.zsh` (Ctrl+R/Ctrl+T/Alt+C) is used.
- `navi repo add` shells out to navi's own git handling, which has been observed to hang
  indefinitely. `install.sh` clones the cheat-sheet repo directly instead.
