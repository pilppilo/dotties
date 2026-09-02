#!/usr/bin/env bash
# Diffs explicitly-installed packages (pacman -Qeq + -Qm) against Omarchy's
# default package manifests to produce the "extras" list for packages.txt.
# Run after installing new apps, then hand-curate into packages.txt.

set -euo pipefail

OMARCHY_PKGS="${OMARCHY_PKGS:-$HOME/omarchy/install/omarchy-base.packages $HOME/omarchy/install/omarchy-other.packages}"

# Create secure temporary files that automatically clean up on exit
TMP_INSTALLED=$(mktemp)
TMP_DEFAULTS=$(mktemp)
trap 'rm -f "$TMP_INSTALLED" "$TMP_DEFAULTS"' EXIT

# Explicitly installed + foreign (AUR/other-repo)
# pacman -Qmq avoids the need for awk
{ pacman -Qeq; pacman -Qmq; } | sort -u > "$TMP_INSTALLED"

# Packages Omarchy installs by default (first word of each manifest line)
# shellcheck disable=SC2086 # Intended word splitting for multiple paths
cat $OMARCHY_PKGS 2>/dev/null | awk '{print $1}' | sort -u > "$TMP_DEFAULTS"

echo "# Extras beyond Omarchy defaults ($(date +%F))"
echo "# Review each line, then curate into ~/packages.txt"
comm -23 "$TMP_INSTALLED" "$TMP_DEFAULTS"
