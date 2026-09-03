#!/usr/bin/env bash
set -Eeuo pipefail

echo '== Native explicitly installed packages =='
pacman -Qneq | sort -u

echo
echo '== Foreign packages (audit only; not installed by bootstrap) =='
pacman -Qmq | sort -u || true

echo
echo '== Flatpaks =='
if command -v flatpak >/dev/null 2>&1; then
  flatpak list --app --columns=application | sort -u
else
  echo 'flatpak not installed'
fi

echo
echo '== External tools =='
if command -v agy >/dev/null 2>&1; then
  printf 'agy: '; agy --version 2>/dev/null || echo installed
else
  echo 'agy: missing'
fi
if command -v nextdns >/dev/null 2>&1; then
  echo 'nextdns: installed'
  systemctl is-active --quiet nextdns && echo 'nextdns service: active' || echo 'nextdns service: inactive'
else
  echo 'nextdns: missing'
fi

echo
echo '== Omarchy theme =='
if command -v omarchy >/dev/null 2>&1; then
  printf 'current: '; omarchy theme current
else
  echo 'omarchy: missing'
fi
if [[ -f "$HOME/software/omarchy-theme.txt" ]]; then
  printf 'tracked: '; awk '!/^[[:space:]]*(#|$)/ { print; exit }' "$HOME/software/omarchy-theme.txt"
else
  echo 'tracked: no manifest'
fi

echo
echo '== Gemini usage plugin =='
plugin_dir="$HOME/src/gemini-plugin"
plugin_link="$HOME/.config/omarchy/plugins/gemini-usage"
if [[ -d "$plugin_dir/.git" ]]; then
  git -C "$plugin_dir" status --short --branch
  printf 'HEAD: '; git -C "$plugin_dir" rev-parse --short HEAD
else
  echo "checkout missing: $plugin_dir"
fi
if [[ -L "$plugin_link" ]]; then
  printf 'link: '; readlink "$plugin_link"
elif [[ -e "$plugin_link" ]]; then
  echo "link path is a real file/directory: $plugin_link"
else
  echo "link missing: $plugin_link"
fi
