# Dotfiles and Software Bootstrap Specification

## 1. Purpose

This repository manages user configuration and provisions a personal Omarchy
installation without depending on the Arch User Repository (AUR).

The system should make a new or repaired machine straightforward to restore
while keeping a human in the loop for authentication, sudo prompts, and
potentially disruptive system changes.

## 2. Design decisions

- Official pacman and Omarchy repositories are the package sources of record.
- AUR packages are not installed or exported as desired dependencies.
- Official vendor curl installers are permitted for tools that do not have a
  suitable official package.
- External installers may remain interactive.
- Authentication is not automated.
- The dotfiles repository is a bare Git repository used with `$HOME` as its
  worktree.
- `gemini-plugin` is the Git repository name.
- `gemini-usage` is the Omarchy plugin ID and must remain stable.
- Curated manifests are the source of truth; generated inventories are audit
  reports only.

## 3. Repository layout

The repository is checked out into the user's home directory through the
bare-repository workflow.

```text
$HOME/
├── .config/
│   └── omarchy/
│       └── shell.json
├── .gitignore
├── bootstrap.sh
├── software/
│   ├── pacman.txt
│   ├── omarchy-base.txt
│   ├── flatpak.txt
│   ├── plugins.txt
│   └── omarchy-theme.txt
├── scripts/
│   ├── export-packages.sh
│   └── inventory-software.sh
└── SPEC.md
```

### 3.1 Tracked configuration

- `.config/omarchy/shell.json` contains the user bar/widget configuration.
- `.config/nextdns/nextdns.conf` is machine-local configuration and must not be
  tracked because it contains a NextDNS profile identifier.
- No credentials, API tokens, private keys, or auth caches may be committed.

The `.gitignore` rules must allow each parent directory as well as the target
files. The implementation should verify important files with:

```bash
git check-ignore -v .config/omarchy/shell.json
git check-ignore -v .config/nextdns/nextdns.conf
```

The shell configuration should not be ignored; the NextDNS command should
report that the machine-local file is ignored.

## 4. Software tracking model

### 4.1 Official packages

`software/pacman.txt` is a manually reviewed list of packages intentionally
needed in addition to the Omarchy baseline. It contains package names only,
one per line, with comments and blank lines allowed.

Example:

```text
# CLI tools
btop
direnv
neovim
ripgrep
```

The bootstrap installs these packages with pacman and must never invoke an
AUR helper.

### 4.2 Omarchy baseline

`software/omarchy-base.txt` is an optional snapshot of explicitly installed
native packages from a known baseline system. It is useful for identifying
candidate additions, but it is not automatically treated as authoritative:
Omarchy may add or remove packages in later releases.

The candidate export is based on:

```bash
pacman -Qneq | sort -u
```

This represents explicitly installed native packages. The export script must
not silently overwrite the curated `software/pacman.txt` file.

### 4.3 Flatpaks

`software/flatpak.txt` contains Flatpak application IDs, one per line. This
file is optional and is only processed when Flatpak is installed and the file
contains entries.

### 4.3.1 Omarchy theme

`software/omarchy-theme.txt` contains the selected Omarchy theme name, one
non-comment line. The bootstrap applies it with `omarchy theme set` after the
dotfiles are checked out. The generated state under
`~/.local/state/omarchy/current/` is not tracked.

### 4.4 External tools

Tools installed outside pacman are represented by explicit, readable
functions in `bootstrap.sh` or a sourced helper. Each tool definition must
specify:

- display name;
- official installation URL or repository;
- expected executable path or command;
- whether sudo is required;
- whether human authentication is required;
- how an already-installed tool is detected.

Initial external tools:

- Antigravity CLI: official installer, expected command `agy`, normally under
  `$HOME/.local/bin/agy`;
- NextDNS CLI: official installer, system service and configuration.

The installer must add `$HOME/.local/bin` to the current script's `PATH`, but
should not depend on the vendor installer modifying shell startup files.

### 4.5 Plugins and repositories

`software/plugins.txt` documents repository, checkout, and installed plugin ID:

```text
gemini-usage|git@github.com:pilppilo/gemini-plugin.git|$HOME/src/gemini-plugin
```

The checkout directory may follow the repository name. The Omarchy plugin
entry must use the stable ID `gemini-usage`.

## 5. Bootstrap phases

### Phase 0: obtain the dotfiles

This phase is documented separately from `bootstrap.sh` because the script
does not exist on a clean machine yet.

It must:

1. install or confirm `git` and `curl`;
2. clone or initialize the bare dotfiles repository at `$HOME/.dotfiles`;
3. configure `$HOME` as its worktree;
4. check out the tracked files without overwriting untracked user files;
5. run `bootstrap.sh` from the checked-out worktree.

The README must include the exact first-machine commands and explain any SSH
key or GitHub access prerequisite.

### Phase 1: preflight

`bootstrap.sh` must:

- use `set -Eeuo pipefail`;
- resolve its own repository/worktree location;
- verify that the operating system is Arch/Omarchy;
- verify required commands;
- check that it is running as the intended user rather than root;
- confirm sudo availability before beginning privileged operations;
- support `--dry-run`;
- print a clear phase name before each operation.

### Phase 2: official packages

Read and validate `software/pacman.txt`, then install the listed packages with
pacman using `--needed`.

### Phase 2.1: Omarchy theme

If `software/omarchy-theme.txt` exists, read its first non-comment line and run
`omarchy theme set <name>`. An empty manifest or failed theme command stops the
bootstrap visibly.

The script must not perform a partial database refresh. A full system update
may be offered as a separate, clearly announced operation requiring human
approval. Package-install failures must stop the bootstrap.

### Phase 3: external tools

Install only missing tools. After each installer completes, verify the
expected executable exists and is runnable.

Antigravity authentication is a separate human step. The script should print
that requirement rather than treating installation as authentication.

### Phase 4: plugin repository

Use:

```bash
PLUGIN_ID="gemini-usage"
PLUGIN_DIR="$HOME/src/gemini-plugin"
PLUGIN_LINK="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
```

If the checkout is missing, clone it. If it already exists, do not overwrite
local changes or silently pull updates. An optional `--update-plugins` mode
may perform a fast-forward-only update after displaying the target repository.

Before creating the link:

- fail if `PLUGIN_DIR` exists but is not a Git checkout;
- fail if `PLUGIN_LINK` is an existing real directory or file;
- allow replacement of an existing symlink;
- verify that the checkout has the expected Omarchy plugin layout.

Create the link with the installed ID as its name:

```bash
mkdir -p "$HOME/.config/omarchy/plugins"
ln -sfnT "$PLUGIN_DIR" "$PLUGIN_LINK"
```

### Phase 5: user configuration

Ensure tracked configuration files are present before applying dependent
system configuration.

`shell.json` must contain the intended `gemini-usage` widget/plugin entry. The
bootstrap should validate that the file is readable and leave unrelated user
customizations intact.

The Omarchy shell normally hot-reloads configuration. If the plugin is not
detected after linking, the script should request or perform an Omarchy shell
reload/rescan and report the result.

### Phase 6: NextDNS

NextDNS configuration is optional and may be interactive.

If `.config/nextdns/nextdns.conf` is absent, print a skip message. If it is
present:

1. install NextDNS if the command is missing using the official installer;
2. confirm the target system configuration path and service definition;
3. back up any existing system configuration before replacement;
4. deploy the tracked file with root ownership and restrictive permissions;
5. enable and start the service;
6. verify that the service is active;
7. perform a DNS health check;
8. stop with an error if the service or health check fails.

The implementation must not use `|| true` to hide a failed DNS setup.

## 6. Command-line options

The initial script should support:

```text
--dry-run              Show intended actions without changing the system
--skip-packages        Skip pacman package installation
--skip-external        Skip external tools
--skip-plugins         Skip repository/plugin setup
--skip-nextdns         Skip NextDNS setup
--update-plugins       Permit fast-forward-only plugin updates
```

Interactive mode is the default. Any noninteractive mode must fail when a
required human action would otherwise prompt indefinitely.

## 7. Export and audit scripts

### `scripts/export-packages.sh`

Produces a reviewed candidate list of explicitly installed native packages.
It must:

- use a temporary file safely;
- sort and deduplicate output;
- never modify the curated package manifest without explicit confirmation;
- clearly label the result as a candidate or baseline export.

### `scripts/inventory-software.sh`

Reports the current state of:

- native pacman packages;
- foreign packages, for audit only;
- Flatpaks;
- Antigravity;
- NextDNS and its systemd service;
- plugin checkout and symlink status.

This report is diagnostic output, not an install manifest.

## 8. Safety and recovery requirements

- Never edit `/usr/share/omarchy/`.
- Never delete an existing user configuration automatically.
- Back up `/etc/nextdns.conf` before replacing it.
- Refuse to replace a real plugin directory with a symlink.
- Fail clearly on missing credentials, inaccessible repositories, or failed
  services.
- Do not commit secrets or generated auth state.
- Keep external installer URLs visible in the script for review.
- Use temporary files for generated data and clean them up on exit.

## 9. Acceptance criteria

The implementation is complete when:

1. A documented clean-machine procedure can obtain the dotfiles and invoke
   `bootstrap.sh`.
2. Running the bootstrap twice produces no unnecessary changes.
3. `software/pacman.txt` installs only the curated official package set.
4. No AUR helper or AUR package is required.
5. Antigravity installs or reports its existing installation correctly.
6. Human authentication requirements are clearly reported.
7. The repository `gemini-plugin` is installed under the Omarchy ID
   `gemini-usage`.
8. Existing real files are not replaced by plugin symlinks.
9. NextDNS setup either succeeds and passes a health check or fails visibly.
10. Package and software inventory scripts produce useful audit reports.
11. Shell configuration remains tracked by the bare dotfiles repository.
12. The selected Omarchy theme is restored from `software/omarchy-theme.txt`.

## 10. Git identity and SSH prerequisites

Git identity and GitHub SSH access are configured during the Omarchy
installation. The bootstrap must not prompt for, create, modify, or upload
Git identity or SSH keys.

The expected layout is:

```text
GitHub remote: git@github.com:pilppilo/dotties.git
Local bare repo: $HOME/.dotfiles
Worktree: $HOME
```

The script may verify the existing identity with:

```bash
git config --global --get user.name
git config --global --get user.email
```

If either value is missing, it must stop with a clear message explaining that
Git identity must be configured during installation.

For an SSH remote, repository access must already be available. The script may
verify the actual repository with:

```bash
git ls-remote git@github.com:pilppilo/dotties.git HEAD
```

If access fails, the script must stop and explain that the user needs to
configure GitHub SSH access before rerunning bootstrap. It must not fall back
to another remote or generate a key.

SSH private keys, public keys, credential files, and GitHub authentication
caches must never be tracked in this repository.

The fresh-machine instructions should assume:

1. Omarchy installation has configured Git name and email;
2. Omarchy installation has configured GitHub SSH access;
3. the user downloads or runs `bootstrap.sh` with the SSH repository remote;
4. bootstrap clones the bare repository and continues provisioning.

The bootstrap command-line interface must not include a `--setup-git` option.
