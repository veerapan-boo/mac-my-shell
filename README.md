# mac-my-shell

Personal zsh + terminal setup: smart autosuggestions, fuzzy Tab-completion, fuzzy history
search, a custom `claude` CLI completion, `navi`'s cheat-sheet picker, and a themed WezTerm
config. Everything installs under `$HOME` — no `sudo`, no Homebrew required, so it works the
same on an admin or a non-admin macOS account.

## Quick start

```bash
git clone git@github.com:veerapan-boo/mac-my-shell.git
cd mac-my-shell
./install.sh
```

Re-running `install.sh` is safe — every step is skipped if its target already exists.
If you already have a `~/.zshrc`, it's backed up to `~/.zshrc.bak.<timestamp>` before
being replaced.

`navi` has no prebuilt macOS binary, so the script installs a minimal, self-contained
`rustup`/`cargo` toolchain under `~/.cargo` and builds it from source. That step alone
takes a few minutes on a fresh machine.

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

- No Homebrew, no `sudo`: everything lives under `$HOME` (`~/.zsh`, `~/.fzf`, `~/.cargo`,
  `~/.local/share/navi`), so this works identically on a locked-down non-admin account.
- `compinit -u` in `~/.zshrc` skips the insecure-directory prompt for zsh completion
  dirs owned by another account (e.g. an admin user on a shared Mac) — otherwise
  `compaudit` hangs waiting for interactive y/n input during shell startup.
- fzf's own `completion.zsh` is intentionally not sourced — it rebinds Tab and silently
  overrides fzf-tab's Tab binding. Only `key-bindings.zsh` (Ctrl+R/Ctrl+T/Alt+C) is used.
- `navi repo add` shells out to navi's own git handling, which has been observed to hang
  indefinitely. `install.sh` clones the cheat-sheet repo directly instead.
