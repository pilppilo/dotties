#!/usr/bin/env bash
# Restore dotfiles on a fresh Omarchy install.
# Usage: bash <(curl -fsSL <raw-github-url>/bootstrap.sh) git@github.com:<you>/dotfiles.git
# or, once cloned anywhere:  ./bootstrap.sh git@github.com:<you>/dotfiles.git
set -euo pipefail

REMOTE="${1:?Usage: bootstrap.sh <git remote url>}"
GIT_DIR="$HOME/.dotfiles"

echo "==> Ensuring git is installed"
command -v git >/dev/null || sudo pacman -S --needed git

echo "==> Cloning $REMOTE into bare repo $GIT_DIR"
if [[ -d "$GIT_DIR" && -n "$(ls -A "$GIT_DIR" 2>/dev/null)" ]]; then
  echo "    $GIT_DIR already exists, skipping clone"
else
  git clone --bare "$REMOTE" "$GIT_DIR"
fi
git --git-dir="$GIT_DIR" config status.showUntrackedFiles no

dotfiles() { git --git-dir="$GIT_DIR" --work-tree="$HOME" "$@"; }

echo "==> Adding dotfiles alias to ~/.bashrc"
grep -q 'alias dotfiles=' ~/.bashrc 2>/dev/null || cat >> ~/.bashrc <<'EOF'

# Dotfiles: bare repo with work-tree at $HOME
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
EOF

echo "==> Checking out files (conflicts are backed up to ~/.dotfiles-backup)"
mkdir -p ~/.dotfiles-backup
if ! dotfiles checkout; then
  echo "    Conflicts found; backing up existing files and re-checking out"
  dotfiles checkout 2>&1 | grep -E '^\s+' | sed 's/^\s*//' | while read -r f; do
    mkdir -p ~/.dotfiles-backup/"$(dirname "$f")"
    mv -v "$HOME/$f" ~/.dotfiles-backup/"$f"
  done
  dotfiles checkout -f
fi

echo "==> Installing extra packages from packages.txt"
if command -v omarchy >/dev/null; then
  repo_pkgs=$(grep -vE '^\s*(#|$)' packages.txt | grep -vx chatgpt || true)
  [[ -n "$repo_pkgs" ]] && omarchy pkg add $repo_pkgs
else
  echo "    omarchy CLI not found — install packages.txt manually:"
  grep -vE '^\s*(#|$)' packages.txt
fi

echo "==> Building self-packaged chatgpt (pilppilo/codex-omarchy)"
if ! pacman -Qi chatgpt >/dev/null 2>&1; then
  [[ -d ~/codex-pkgbuild ]] || git clone https://github.com/pilppilo/codex-omarchy ~/codex-pkgbuild
  (cd ~/codex-pkgbuild && makepkg -si)
else
  echo "    chatgpt already installed"
fi

echo "==> Enabling user systemd units"
for unit in hermes-gateway.service voxtype.service; do
  [[ -f ~/.config/systemd/user/$unit ]] && systemctl --user enable "$unit" || true
done

echo "==> SSH key setup (keys are NOT stored in this repo)"
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  ssh-keygen -t ed25519 -C "$(git --git-dir="$GIT_DIR" config user.email 2>/dev/null || echo "$USER@$(hostname)")"
fi
echo ""
echo "Your public key (add it at https://github.com/settings/keys):"
cat ~/.ssh/id_ed25519.pub

echo ""
echo "==> Done. Reminders:"
echo "  - Review git identity: git config --global user.name / user.email"
echo "  - Restart your shell or: source ~/.bashrc"
echo "  - Old conflicting files (if any) are in ~/.dotfiles-backup"
