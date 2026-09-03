#!/usr/bin/env bash
# Restore dotfiles on a fresh Omarchy install.
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/pilppilo/dotties/master/bootstrap.sh) git@github.com:pilppilo/dotties.git
# or, once cloned anywhere:  ./bootstrap.sh git@github.com:pilppilo/dotties.git
set -Eeuo pipefail

REMOTE="git@github.com:pilppilo/dotties.git"
GIT_DIR="$HOME/.dotfiles"
DRY_RUN=0
SKIP_PACKAGES=0
SKIP_EXTERNAL=0
SKIP_PLUGINS=0
SKIP_NEXTDNS=0
UPDATE_PLUGINS=0

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [options] [git-remote]

Options:
  --dry-run         Show intended actions without changing the system
  --skip-packages   Skip official package and Flatpak installation
  --skip-external   Skip external user-space tools
  --skip-plugins    Skip Omarchy plugin setup
  --skip-nextdns    Skip NextDNS setup
  --update-plugins  Fast-forward an existing plugin checkout
  -h, --help        Show this help
USAGE
}

while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-external) SKIP_EXTERNAL=1 ;;
    --skip-plugins) SKIP_PLUGINS=1 ;;
    --skip-nextdns) SKIP_NEXTDNS=1 ;;
    --update-plugins) UPDATE_PLUGINS=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) REMOTE="$1" ;;
  esac
  shift
done

export PATH="$HOME/.local/bin:$PATH"

if (( DRY_RUN )); then
  echo "Dry run: no files, packages, services, or repositories will be changed."
  echo "Would use bare repository: $GIT_DIR"
  echo "Would use worktree: $HOME"
  [[ -f "$HOME/software/pacman.txt" ]] && echo "Would install packages from $HOME/software/pacman.txt"
  [[ -f "$HOME/software/omarchy-theme.txt" ]] && echo "Would apply Omarchy theme from $HOME/software/omarchy-theme.txt"
  [[ -f "$HOME/software/plugins.txt" ]] && echo "Would configure plugins from $HOME/software/plugins.txt"
  [[ -f "$HOME/.config/nextdns/nextdns.conf" ]] && echo "Would configure NextDNS"
  exit 0
fi

echo "==> Ensuring git is installed"
command -v git >/dev/null || sudo pacman -S --needed git

git config --global --get user.name >/dev/null 2>&1 || {
  echo "Git user.name is not configured; configure it during Omarchy installation." >&2
  exit 1
}
git config --global --get user.email >/dev/null 2>&1 || {
  echo "Git user.email is not configured; configure it during Omarchy installation." >&2
  exit 1
}

if [[ "$REMOTE" == git@* || "$REMOTE" == ssh://* ]]; then
  git ls-remote "$REMOTE" HEAD >/dev/null 2>&1 || {
    echo "Cannot access SSH remote: $REMOTE" >&2
    echo "Add the displayed public key to GitHub, then rerun bootstrap.sh." >&2
    exit 1
  }
fi

echo "==> Preparing bare repo $GIT_DIR"
if [[ -e "$GIT_DIR" ]]; then
  [[ -d "$GIT_DIR" ]] || { echo "$GIT_DIR is not a directory" >&2; exit 1; }
  [[ "$(git --git-dir="$GIT_DIR" rev-parse --is-bare-repository 2>/dev/null || true)" == true ]] || {
    echo "$GIT_DIR is not a bare Git repository" >&2; exit 1;
  }
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

echo "==> Checking out files"
if ! dotfiles checkout; then
  echo "Checkout conflicts detected. No files were moved or overwritten." >&2
  echo "Review the conflicting paths, back them up manually, then rerun bootstrap.sh." >&2
  exit 1
fi

if (( ! SKIP_PACKAGES )); then
  PACKAGE_FILE="$HOME/software/pacman.txt"
  [[ -f "$PACKAGE_FILE" ]] || { echo "Missing package manifest: $PACKAGE_FILE" >&2; exit 1; }
  mapfile -t packages < <(sed -E '/^[[:space:]]*(#|$)/d' "$PACKAGE_FILE")
  if ((${#packages[@]})); then
    echo "==> Installing official packages from $PACKAGE_FILE"
    sudo pacman -S --needed "${packages[@]}"
  fi
fi

FLATPAK_FILE="$HOME/software/flatpak.txt"
if (( ! SKIP_PACKAGES )) && [[ -f "$FLATPAK_FILE" ]] && command -v flatpak >/dev/null 2>&1; then
  mapfile -t flatpaks < <(sed -E '/^[[:space:]]*(#|$)/d' "$FLATPAK_FILE")
  if ((${#flatpaks[@]})); then
    echo "==> Installing Flatpaks from $FLATPAK_FILE"
    flatpak install --user flathub "${flatpaks[@]}"
  fi
fi

THEME_FILE="$HOME/software/omarchy-theme.txt"
if [[ -f "$THEME_FILE" ]]; then
  theme_name="$(awk '!/^[[:space:]]*(#|$)/ { print; exit }' "$THEME_FILE")"
  [[ -n "$theme_name" ]] || { echo "Theme manifest is empty: $THEME_FILE" >&2; exit 1; }
  command -v omarchy >/dev/null 2>&1 || { echo "omarchy command is required to restore the selected theme" >&2; exit 1; }
  echo "==> Applying Omarchy theme: $theme_name"
  omarchy theme set "$theme_name"
fi

if (( ! SKIP_EXTERNAL )) && [[ ! -x "$HOME/.local/bin/agy" ]]; then
  echo "==> Installing Antigravity CLI from its official installer"
  bash -c 'curl -fsSL https://antigravity.google/cli/install.sh | bash'
fi
if (( ! SKIP_EXTERNAL )); then
  [[ -x "$HOME/.local/bin/agy" ]] || { echo "Antigravity installation failed" >&2; exit 1; }
  echo "    Antigravity authentication may be required on first use: agy"
fi

if (( ! SKIP_PLUGINS )); then
  PLUGIN_MANIFEST="$HOME/software/plugins.txt"
  [[ -f "$PLUGIN_MANIFEST" ]] || { echo "Missing plugin manifest: $PLUGIN_MANIFEST" >&2; exit 1; }
  while IFS='|' read -r plugin_id plugin_url plugin_dir; do
    [[ -z "$plugin_id" || "$plugin_id" == \#* ]] && continue
    plugin_dir="${plugin_dir//\$HOME/$HOME}"
    plugin_link="$HOME/.config/omarchy/plugins/$plugin_id"
    mkdir -p "$(dirname "$plugin_dir")" "$(dirname "$plugin_link")"
    if [[ ! -e "$plugin_dir" ]]; then
      git clone "$plugin_url" "$plugin_dir"
    elif [[ ! -d "$plugin_dir/.git" ]]; then
      echo "Plugin checkout is not a Git repo: $plugin_dir" >&2
      exit 1
    elif (( UPDATE_PLUGINS )); then
      git -C "$plugin_dir" pull --ff-only
    fi
    [[ -f "$plugin_dir/manifest.json" ]] || { echo "Missing plugin manifest: $plugin_dir/manifest.json" >&2; exit 1; }
    if [[ -e "$plugin_link" && ! -L "$plugin_link" ]]; then
      echo "Refusing to replace existing plugin path: $plugin_link" >&2
      exit 1
    fi
    ln -sfnT "$plugin_dir" "$plugin_link"
  done < "$PLUGIN_MANIFEST"
  [[ -f "$HOME/.config/omarchy/shell.json" ]] || { echo "Missing shell.json" >&2; exit 1; }
  grep -q 'gemini-usage' "$HOME/.config/omarchy/shell.json" || {
    echo "shell.json does not contain gemini-usage" >&2; exit 1;
  }
  if command -v omarchy >/dev/null 2>&1; then
    omarchy restart shell
  fi
fi

if (( ! SKIP_NEXTDNS )) && [[ -f "$HOME/.config/nextdns/nextdns.conf" ]]; then
  echo "==> Installing/configuring NextDNS"
  if ! command -v nextdns >/dev/null 2>&1; then
    sh -c "$(curl -sL https://nextdns.io/install)"
  fi
  [[ -x "$(command -v nextdns)" ]] || { echo "NextDNS installation failed" >&2; exit 1; }
  target=/etc/nextdns.conf
  backup="${target}.bootstrap-backup.$(date +%Y%m%d%H%M%S)"
  [[ ! -e "$target" ]] || sudo cp -p "$target" "$backup"
  sudo install -o root -g root -m 600 "$HOME/.config/nextdns/nextdns.conf" "$target"
  sudo systemctl enable --now nextdns
  systemctl is-active --quiet nextdns || { echo "NextDNS service is not active" >&2; exit 1; }
  if command -v dig >/dev/null 2>&1; then
    dig @127.0.0.1 example.com +short >/dev/null || { echo "NextDNS health check failed" >&2; exit 1; }
  fi
fi

echo "==> Enabling user systemd units"
systemctl --user daemon-reload
for unit in hermes-gateway.service voxtype.service; do
  if [[ -f "$HOME/.config/systemd/user/$unit" ]]; then
    systemctl --user enable "$unit"
  fi
done

echo ""
echo "==> Done. Reminders:"
echo "  - Review git identity: git config --global user.name / user.email"
echo "  - Restart your shell or: source ~/.bashrc"
echo "  - Checkout conflicts are never overwritten automatically"
