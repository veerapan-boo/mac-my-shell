#!/usr/bin/env bash
# mac-my-shell — bootstrap a smart zsh setup on a new machine.
#
# Installs everything under $HOME (no sudo, no Homebrew required — works the
# same whether the account is an admin or not):
#   - zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search, fzf-tab
#   - fzf (built from source)
#   - navi (built from source via a self-contained rustup/cargo toolchain —
#     there is no prebuilt macOS binary in navi's GitHub releases)
#   - the denisidoro/cheats community cheat-sheet repo for navi
#   - this repo's ~/.zshrc and the custom `claude` CLI completion generator
#
# Safe to re-run: every step is skipped if its target already exists.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_DIR="$HOME/.zsh"
PLUGINS_DIR="$ZSH_DIR/plugins"
COMPLETIONS_DIR="$ZSH_DIR/completions"

log() { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
skip() { printf '\033[2m    skip: %s (already present)\033[0m\n' "$1"; }

clone_plugin() {
  local url="$1" dest="$2"
  if [ -d "$dest" ]; then
    skip "$dest"
  else
    log "cloning $(basename "$dest")"
    git clone --quiet --depth 1 "$url" "$dest"
  fi
}

mkdir -p "$PLUGINS_DIR" "$COMPLETIONS_DIR"

# ---- zsh plugins ----
clone_plugin https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions"
clone_plugin https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGINS_DIR/zsh-syntax-highlighting"
clone_plugin https://github.com/zsh-users/zsh-history-substring-search "$PLUGINS_DIR/zsh-history-substring-search"
clone_plugin https://github.com/Aloxaf/fzf-tab "$PLUGINS_DIR/fzf-tab"

# ---- fzf ----
if [ -x "$HOME/.fzf/bin/fzf" ]; then
  skip "$HOME/.fzf"
else
  log "cloning + building fzf"
  git clone --quiet --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --bin --no-update-rc --no-key-bindings --no-completion
fi

# ---- rustup + cargo (only needed to build navi) ----
if ! command -v navi >/dev/null 2>&1; then
  if ! command -v cargo >/dev/null 2>&1; then
    log "installing rustup (minimal profile, self-contained under ~/.cargo)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  fi
  # shellcheck disable=SC1090
  source "$HOME/.cargo/env"
  log "building navi from source (no prebuilt macOS binary exists) — this takes a few minutes"
  cargo install navi
else
  skip "navi ($(navi --version))"
fi

# ---- navi community cheat sheets ----
NAVI_CHEATS="$HOME/.local/share/navi/cheats/denisidoro__cheats"
if [ -d "$NAVI_CHEATS" ]; then
  skip "$NAVI_CHEATS"
else
  log "cloning navi's community cheat-sheet repo"
  mkdir -p "$(dirname "$NAVI_CHEATS")"
  # `navi repo add` shells out to its own git handling, which has been
  # observed to hang indefinitely — clone directly into navi's expected path.
  git clone --quiet --depth 1 https://github.com/denisidoro/cheats.git "$NAVI_CHEATS"
fi

# ---- completion generator ----
cp "$REPO_DIR/config/zsh/completions/generate-claude-completion.py" "$COMPLETIONS_DIR/generate-claude-completion.py"

# ---- ~/.zshrc ----
if [ -e "$HOME/.zshrc" ] && ! cmp -s "$REPO_DIR/config/zshrc" "$HOME/.zshrc"; then
  backup="$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
  log "backing up existing ~/.zshrc to $backup"
  cp "$HOME/.zshrc" "$backup"
fi
cp "$REPO_DIR/config/zshrc" "$HOME/.zshrc"
log "installed ~/.zshrc"

# ---- claude CLI completion (only if the claude CLI is present) ----
if command -v claude >/dev/null 2>&1; then
  log "generating _claude completion from the local claude --help output"
  python3 "$COMPLETIONS_DIR/generate-claude-completion.py" || true
else
  skip "_claude completion (claude CLI not on PATH yet)"
fi

echo
log "done — open a new terminal, or run: source ~/.zshrc"
