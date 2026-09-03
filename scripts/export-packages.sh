#!/usr/bin/env bash
# Export a reviewed candidate list of explicitly installed native packages.
set -Eeuo pipefail

output="${1:-/tmp/pacman-native-candidates.txt}"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

pacman -Qneq | sort -u > "$tmp"
{
  echo "# Candidate native packages exported on $(date +%F)"
  echo "# Review manually; this file does not modify ~/software/pacman.txt."
  cat "$tmp"
} > "$output"

echo "Wrote candidate package list to $output"
