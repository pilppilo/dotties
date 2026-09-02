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
- `packages.txt` — extra packages to install on a fresh machine (Brewfile-equivalent)

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
~/scripts/export-packages.sh        # diff installed vs Omarchy defaults
# hand-curate output into ~/packages.txt, then commit
```

## Restoring on a fresh Omarchy install

```bash
git clone git@github.com:<you>/dotfiles.git ~/dotfiles-repo && ~/dotfiles-repo/bootstrap.sh
# or the raw-URL one-liner printed by GitHub after the first push
```

Bootstrap: clones the repo to a bare `~/.dotfiles`, checks everything out
(conflicting files are moved to `~/.dotfiles-backup/`), installs `packages.txt`
via `omarchy pkg add`, enables user systemd units, and generates a **fresh SSH
key** (print the public key and add it at https://github.com/settings/keys).
SSH private keys are deliberately never stored in this repo.

If anything conflicts or looks wrong, restore from `~/.dotfiles-backup/` or
reset a specific file with `omarchy refresh config <path>`.

## Optional upgrade: 1Password SSH agent

Instead of per-machine keys, install 1Password + the `op` CLI and point the
SSH agent at the vault (`SSH_AUTH_SOCK=~/1password/t/agent.sock` on Linux,
plus `IdentityAgent` in `~/.ssh/config`), and inject secret env vars per
command with `op run --env-file=... -- <cmd>`. See
[Adam Tuttle's write-up][tuttle] for the full pattern.

[atlassian]: https://www.atlassian.com/git/tutorials/dotfiles
[tuttle]: https://adamtuttle.codes/blog/2026/getting-my-shit-together-dotfiles-brewfile-1password-ssh-agent/
