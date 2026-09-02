#!/usr/bin/env bash
# Diffs explicitly-installed packages (pacman -Qeq + -Qm) against Omarchy's
# default package manifests to produce the "extras" list for packages.txt.
# Run after installing new apps, then hand-curate into packages.txt.

set -euo pipefail

OMARCHY_PKGS="${OMARCHY_PKGS:-$HOME/omarchy/install/omarchy-base.packages $HOME/omarchy/install/omarchy-other.packages}"

# Explicitly installed + foreign (AUR/other-repo)
{ pacman -Qeq; pacman -Qm; } | sort -u > /tmp/installed.$$

# Packages Omarchy installs by default (first word of each manifest line)
cat $OMARCHY_PKGS 2>/dev/null | awk '{print $1}' | sort -u > /tmp/omarchy-defaults.$$

echo "# Extras beyond Omarchy defaults ($(date +%F))"
echo "# Review each line, then curate into ~/packages.txt"
comm -23 /tmp/installed.$$ /tmp/omarchy-defaults.$$

rm -f /tmp/installed.$$ /tmp/omarchy-defaults.$$
