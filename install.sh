#!/usr/bin/env bash
# mac-my-shell — bootstrap a smart zsh setup on a new machine.
#
# Works on macOS and Linux. Everything installs under $HOME (no Homebrew) —
# the one exception is `zsh` itself on Linux, which needs `apt` since there's
# no sudo-free way to get a zsh binary onto the box:
#   - zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search, fzf-tab
#   - fzf (prebuilt binary, fetched by fzf's own installer)
#   - navi — prebuilt binary on Linux; built from source via a self-contained
#     rustup/cargo toolchain on macOS (no prebuilt macOS binary exists)
#   - the denisidoro/cheats community cheat-sheet repo for navi
#   - this repo's ~/.zshrc and the custom `claude` CLI completion generator
#   - the WezTerm tab/status-bar config — macOS only, skipped on Linux
#
# Safe to re-run: every step is skipped if its target already exists.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_DIR="$HOME/.zsh"
PLUGINS_DIR="$ZSH_DIR/plugins"
COMPLETIONS_DIR="$ZSH_DIR/completions"
OS="$(uname -s)"

log() { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
skip() { printf '\033[2m    skip: %s (already present)\033[0m\n' "$1"; }

# ---- zsh (macOS ships it; Linux needs it from the system package manager —
# the one step in this script that isn't purely $HOME, since there's no
# sudo-free way to get a zsh binary onto a Linux box) ----
if command -v zsh >/dev/null 2>&1; then
  skip "zsh ($(zsh --version))"
elif [ "$OS" = "Linux" ]; then
  log "installing zsh via apt (needs sudo)"
  sudo apt-get update -qq
  sudo apt-get install -y zsh
else
  echo "zsh not found and this isn't Linux — install it manually first" >&2
  exit 1
fi

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

# ---- navi ----
if command -v navi >/dev/null 2>&1; then
  skip "navi ($(navi --version))"
elif [ "$OS" = "Linux" ]; then
  # navi ships prebuilt Linux binaries (no macOS releases exist, which is why
  # the macOS branch below builds from source instead).
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) NAVI_ASSET_ARCH="x86_64-unknown-linux-musl" ;;
    aarch64) NAVI_ASSET_ARCH="aarch64-unknown-linux-gnu" ;;
    *) echo "no prebuilt navi binary for arch $ARCH — install navi manually" >&2; exit 1 ;;
  esac
  NAVI_VERSION="$(curl -fsSL https://api.github.com/repos/denisidoro/navi/releases/latest \
    | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"
  log "downloading navi ${NAVI_VERSION} (${NAVI_ASSET_ARCH})"
  mkdir -p "$HOME/.local/bin"
  # the release tarball's member is "./navi", not "navi" -- don't pass a
  # member name or tar's exact-match miss breaks the curl pipe (error 23).
  curl -fsSL "https://github.com/denisidoro/navi/releases/download/${NAVI_VERSION}/navi-${NAVI_VERSION}-${NAVI_ASSET_ARCH}.tar.gz" \
    | tar -xz -C "$HOME/.local/bin"
  chmod +x "$HOME/.local/bin/navi"
else
  # macOS: rustup + cargo, self-contained under ~/.cargo, only needed here
  if ! command -v cargo >/dev/null 2>&1; then
    log "installing rustup (minimal profile, self-contained under ~/.cargo)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  fi
  # shellcheck disable=SC1090
  source "$HOME/.cargo/env"
  log "building navi from source (no prebuilt macOS binary exists) — this takes a few minutes"
  cargo install navi
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

# ---- ~/.config/wezterm ----
# macOS-only: this config assumes a local WezTerm GUI and status.sh shells
# out to macOS-only tools (top -l, vm_stat, sysctl). Skipped on Linux —
# irrelevant on a headless box, and status.sh isn't ported (yet).
if [ "$OS" = "Darwin" ]; then
  WEZTERM_DIR="$HOME/.config/wezterm"
  mkdir -p "$WEZTERM_DIR/scripts"
  if [ -e "$WEZTERM_DIR/wezterm.lua" ] && ! cmp -s "$REPO_DIR/config/wezterm/wezterm.lua" "$WEZTERM_DIR/wezterm.lua"; then
    backup="$WEZTERM_DIR/wezterm.lua.bak.$(date +%Y%m%d%H%M%S)"
    log "backing up existing wezterm.lua to $backup"
    cp "$WEZTERM_DIR/wezterm.lua" "$backup"
  fi
  cp "$REPO_DIR/config/wezterm/wezterm.lua" "$WEZTERM_DIR/wezterm.lua"
  cp "$REPO_DIR/config/wezterm/scripts/status.sh" "$WEZTERM_DIR/scripts/status.sh"
  chmod +x "$WEZTERM_DIR/scripts/status.sh"
  log "installed ~/.config/wezterm"
else
  skip "~/.config/wezterm (macOS/GUI-only, not applicable on Linux)"
fi

# ---- default login shell ----
ZSH_PATH="$(command -v zsh)"
if [ "$SHELL" = "$ZSH_PATH" ]; then
  skip "default shell (already $ZSH_PATH)"
else
  log "setting $ZSH_PATH as default login shell"
  if [ "$OS" = "Linux" ] && ! grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi
  sudo chsh -s "$ZSH_PATH" "$USER"
fi

echo
log "done — log out/in (or open a new terminal) to pick up zsh as your shell"
