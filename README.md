# dotfiles

Personal Omarchy (Arch + Hyprland) dotfiles, managed as a bare git repo with
the work-tree at `$HOME` (the classic [Atlassian dotfiles technique][atlassian]).

## What's tracked

- `~/.config/hypr/` — Hyprland `.lua` configs (monitors, bindings, input, look'n'feel, autostart, hyprsunset, xdph)
- `~/.config/omarchy/shell.json` + `extensions/omarchy-menu.jsonc` — bar layout, menus
- `~/.config/git/config` — git identity + aliases
- `~/.bashrc`, `~/.bash_profile`, `~/.profile`, `~/.XCompose`
- App configs that don't ship with Omarchy: `opencode`, `voxtype`, `herdr`, `mise`, `lazygit`, `btop`
- User systemd units: `hermes-gateway.service`, `voxtype.service`
- `software/pacman.txt` — curated official packages to install on a fresh machine
- `software/plugins.txt` — tracked Omarchy plugin repositories and IDs
- `software/flatpak.txt` — optional Flatpak application IDs
- `software/omarchy-theme.txt` — selected Omarchy theme to restore
- `SPEC.md` — implementation and safety requirements

Stock-unchanged configs (foot, kitty, tmux, starship, …) are **not** tracked —
Omarchy's defaults restore them, keeping the repo small and diffs meaningful.

## Never commit secrets

`.gitignore` is default-deny: nothing is tracked unless explicitly whitelisted.
`~/.ssh/`, token files (`~/hftoken`), browser profiles, and `~/.config/Code/`
are excluded and must never be whitelisted. Before pushing anything new:

```bash
dotfiles status            # only expected files
git --git-dir=$HOME/.dotfiles ls-files | grep -iE 'ssh|token|key'
```

## Daily routine

```bash
$EDITOR ~/.config/hypr/bindings.lua   # edit anything
dotfiles add -u                       # stage tracked-file changes
dotfiles commit -m "tweak bindings"
dotfiles push
```

After `omarchy-update`, review what upstream rewrote:

```bash
dotfiles diff
dotfiles add -u && dotfiles commit -m "post-update snapshot"
```

## Package list maintenance

After installing new apps:

```bash
~/scripts/export-packages.sh        # export a reviewable native-package candidate list
# hand-curate approved entries into ~/software/pacman.txt, then commit
```

## Restoring on a fresh Omarchy install

```bash
curl -fsSL https://raw.githubusercontent.com/pilppilo/dotties/master/bootstrap.sh \
  -o /tmp/bootstrap.sh
bash /tmp/bootstrap.sh git@github.com:pilppilo/dotties.git
```

Bootstrap: clones the repo to a bare `~/.dotfiles`, checks everything out,
installs `software/pacman.txt` with pacman, applies the selected Omarchy theme,
installs official external tools, configures tracked Omarchy plugins and
optional local NextDNS, and enables tracked user systemd units. Conflicting files are not
overwritten automatically. Git identity and GitHub SSH access are expected to
be configured during the Omarchy installation; private keys are never stored
in this repo.

NextDNS configuration is intentionally machine-local and is not tracked. If
you use NextDNS, create `~/.config/nextdns/nextdns.conf` yourself before
running bootstrap; the script skips NextDNS when that file is absent.

Useful options include `--dry-run`, `--skip-packages`,
`--skip-external`, `--skip-plugins`, `--skip-nextdns`, and
`--update-plugins`.

If anything conflicts or looks wrong, the bootstrap stops without overwriting
the conflicting file. Resolve the conflict manually, then rerun it. Reset a
specific Omarchy file with `omarchy refresh config <path>` when appropriate.

## Optional upgrade: 1Password SSH agent

Instead of per-machine keys, install 1Password + the `op` CLI and point the
SSH agent at the vault (`SSH_AUTH_SOCK=~/1password/t/agent.sock` on Linux,
plus `IdentityAgent` in `~/.ssh/config`), and inject secret env vars per
command with `op run --env-file=... -- <cmd>`. See
[Adam Tuttle's write-up][tuttle] for the full pattern.

[atlassian]: https://www.atlassian.com/git/tutorials/dotfiles
[tuttle]: https://adamtuttle.codes/blog/2026/getting-my-shit-together-dotfiles-brewfile-1password-ssh-agent/
