# NixOS Configuration

## Daily commands

Run these commands from `~/nixos-config`. Checks and builds do not activate the configuration.

| Command | Inputs | Effect |
| --- | --- | --- |
| `nix fmt` | Locked | Format and lint repository files |
| `just check` | Locked, real private inputs | Evaluate all hosts and run the checks |
| `just check-public` | Locked, both private inputs replaced by dummy inputs | Reproduce public CI |
| `just build` | Locked, real private inputs | Build the current host without activation |
| `just switch` | Locked, real private inputs | Run `check`, then build and activate the current host |
| `just check-local` | Local Pi and Hyprland checkouts; locked private inputs | Check sibling development changes |
| `just build-local` | Local Pi and Hyprland checkouts; locked private inputs | Build sibling development changes without activation |

`check`, `build`, and `switch` use the same input revisions. The local variants do not change `flake.lock`. Publish tested sibling changes and update the lock before using `switch`.

`just check` is the trusted check with real private inputs. Public CI cannot validate private work settings or secret files. Its dummy inputs contain an explicit `.nixos-config-ci` marker. Mixed real and dummy inputs are rejected. Missing real secret files or required work modules are errors.

The remaining check covers formatting. Flake validation also evaluates the host configurations. It does not boot hosts or test microphones and desktop sessions.

## Where to make changes

```text
flake.nix                         Inputs and import-tree entry point
modules/nixos-configurations.nix Host discovery and shared package set
modules/hosts/<hostname>.nix     Host hardware, role, and feature selection
modules/roles/                  Shared feature groups
modules/<category>/             Feature settings (aspects)
hosts/<hostname>/               Raw hardware, disk, and host UI files
lib/private-inputs.nix          Private-input validation
```

`import-tree` loads Nix files under `modules/`. An aspect is a named NixOS module under `flake.modules.nixos`. Several files can contribute to the same aspect. A definition named `hosts/<hostname>` creates a host output automatically.

To add a feature, put its settings in an aspect and attach it to a host or role. To extend an existing aspect, edit its owning file; do not add a second import. Keep raw helper modules outside `modules/` so import-tree does not load them as flake modules.

Git settings belong to `modules/dev/git.nix`. Account and Home Manager setup belong to `modules/base/users.nix`. Host entry points select kernel policy. Existing hosts retain the latest kernel; a new host uses the nixpkgs default unless it selects another kernel. Only the dual-boot `amdep` host uses local time in its hardware clock. Keep `stateVersion` values unchanged during routine updates.

## Related repositories

| Repository | Local checkout needed for | Ownership |
| --- | --- | --- |
| `~/nixos-config` | Runtime configuration and maintenance | Hosts, roles, container tools, Claude settings |
| `~/nixos-hyprland` | Desktop runtime; local checks and builds | Shared Hyprland and DMS settings |
| `~/nixos-pi` | Local checks/builds and Pi development | Pi package, SDK, pinned subagents, extensions, skills |
| `~/nixos-nvim` | Neovim development | Editor configuration |
| `~/nixos-secrets` | Secret updates | Encrypted secrets and age recipients |
| `~/nixos-work` | Private work configuration updates | `github`, `cloud`, and `servers` modules |

Locked builds fetch the inputs they need. A local secrets or work checkout is not required for a locked build, but GitHub SSH access is required when those inputs are not cached.

Hyprland loads Lua files from writable checkouts. DMS settings and Claude settings also use writable files. **A Nix generation rollback does not restore those files.** Record their revisions and review their Git changes separately. Do not assume that an old system generation contains an old desktop configuration.

## Update inputs

For a sibling change, run its own checks, publish it, then update only that input:

```bash
nix flake update nixos-pi
just check
just build
```

Use `nix flake update` for a complete dependency update. Review the lock diff before applying it. Some package inputs intentionally use separate nixpkgs revisions; do not add `follows` without checking that package's compatibility.

Pi and `pi-subagents` are packaged together in `nixos-pi`. Its runtime check prevents a return to the standalone package that lacks the SDK. Restart Pi after applying a runtime update.

## Hosts

Hosts are defined as `modules/hosts/<hostname>.nix` aspects and auto-discovered. Deploy with `--flake ~/nixos-config#<hostname>`.

| Host | Type | Notes |
| ------- | ------------------- | ------------------------------------------- |
| amdep | Workstation | Full desktop, dual-boot |
| fium | Server | Self-hosted monitoring, ZFS storage |
| minidesk | Server | Work configuration |
| t14g6 | ThinkPad laptop | Full desktop, TLP, nixos-hardware module |

## Deploy with nixos-anywhere

Secrets (SSH keys, user password) need the host's age key to decrypt. Ship the key during deploy with `--extra-files` so the credentials are available on first boot. Desktop configuration also requires the checkouts in the post-install checklist. The directory structure inside the extra-files dir mirrors the root filesystem.

### New host or first install

First add `modules/hosts/<hostname>.nix` (aspect module) and raw files under `hosts/<hostname>/`, then add the matching secret files. Then run the install from the deploying machine:

1. Generate an age key for the new host:

   ```bash
   mkdir -p /tmp/extra-files/var/lib/sops-nix
   age-keygen -o /tmp/extra-files/var/lib/sops-nix/key.txt
   chmod 600 /tmp/extra-files/var/lib/sops-nix/key.txt
   age-keygen -y /tmp/extra-files/var/lib/sops-nix/key.txt
   ```

1. Add the public key + creation rule to `~/nixos-secrets/.sops.yaml`

1. Create secrets file: `sops secrets/<hostname>.yaml`

1. Re-encrypt common secrets: `sops updatekeys secrets/common.yaml`

1. Push nixos-secrets, then `nix flake update nixos-secrets` in nixos-config, push

1. Boot target from [NixOS Minimal ISO](https://nixos.org/download/), set root password (`passwd`), get IP (`ip a`)

1. Deploy:

   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --extra-files /tmp/extra-files \
     --flake ~/nixos-config#<hostname> root@<ip>
   ```

1. Save the key (`/tmp/extra-files/var/lib/sops-nix/key.txt`) to KeePass for future reinstalls

1. Clean up: `rm -rf /tmp/extra-files`

### Reinstalling an existing declared host

All from the deploying machine. No sops changes needed, same key, same encryption.

1. Get the host's age key from KeePass:

   ```bash
   mkdir -p /tmp/extra-files/var/lib/sops-nix
   vim /tmp/extra-files/var/lib/sops-nix/key.txt
   chmod 600 /tmp/extra-files/var/lib/sops-nix/key.txt
   ```

1. Boot target, deploy:

   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --extra-files /tmp/extra-files \
     --flake ~/nixos-config#<hostname> root@<ip>
   ```

1. Clean up: `rm -rf /tmp/extra-files`

### Register a headless server with Tailscale

Server hosts can register on first boot with a one-use Tailscale auth key. No SOPS change is needed for this key. Use a non-ephemeral key. If device approval is enabled, use a pre-approved key. Tailnet policy must permit Tailscale SSH; exit-node approval is separate.

Servers use `nixos-anywhere`. Before deployment, run these commands in Bash on the deploying machine. Add the key to the same extra-files directory as the host's age key:

```bash
install -d -m 700 /tmp/extra-files/var/lib/tailscale
(read -rsp 'Tailscale auth key: ' key; echo
 test -n "$key" || exit 1
 umask 077
 printf '%s' "$key" > /tmp/extra-files/var/lib/tailscale/bootstrap-auth-key)
chmod 600 /tmp/extra-files/var/lib/tailscale/bootstrap-auth-key
```

Deploy with the prepared directory:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --extra-files /tmp/extra-files \
  --flake ~/nixos-config#<hostname> root@<ip>
```

Replace `<hostname>` and `<ip>` with the target host name and installer IP address. Delete the local extra-files directory after successful deployment: `rm -rf /tmp/extra-files`.

The file is on the installed disk, not in Git or the Nix store. On boot, the server uses it to register with Tailscale and enable Tailscale SSH. The service deletes the file only after Tailscale reports `Running`. Failed registration keeps the key and retries after 30 seconds. Each attempt has a 120-second timeout. The server needs working network access.

Without the file, registration is skipped. An existing Tailscale identity continues to work. A new server without an identity remains inaccessible through Tailscale. If authentication is required later, provide a fresh key at `/var/lib/tailscale/bootstrap-auth-key` through the console and run `sudo systemctl restart tailscaled-autoconnect`.

Inspect registration with `journalctl -u tailscaled-autoconnect`. This setup does not enable OpenSSH.

### Generating hardware-configuration.nix

Use this when deploying to new hardware or if the existing hardware config is wrong. This does a full install, not just config generation.

```bash
nix run github:nix-community/nixos-anywhere -- \
  --extra-files /tmp/extra-files \
  --generate-hardware-config nixos-generate-config ./hosts/<hostname>/hardware-configuration.nix \
  --flake ~/nixos-config#<hostname> root@<ip>
```

## Secrets (sops-nix + age)

Secrets repo: `git@github.com:kevinpita/nixos-secrets.git` -> `~/nixos-secrets`

Admin key and host age keys are backed up in KeePass. Restore admin key to `~/.config/sops/age/keys.txt` (chmod 600).

## Post-install checklist

The shipped age key provides the SSH keys and user password. On a desktop, use a text console to create the required checkouts before starting the desktop session.

1. Clone the host configuration:

   ```bash
   git clone git@github.com:kevinpita/nixos-config.git ~/nixos-config
   ```

1. On desktop hosts, clone Hyprland and select the revision in the lock:

   ```bash
   git clone git@github.com:kevinpita/nixos-hyprland.git ~/nixos-hyprland
   git -C ~/nixos-hyprland checkout --detach \
     "$(jq -r '.nodes["nixos-hyprland"].locked.rev' ~/nixos-config/flake.lock)"
   ```

   For later Hyprland development, create a branch from this revision. Review writable settings separately from Nix updates.

1. If you need local development commands, clone the missing sibling checkouts:

   ```bash
   git clone git@github.com:kevinpita/nixos-pi.git ~/nixos-pi
   # Headless hosts also need this checkout for check-local and build-local.
   test -d ~/nixos-hyprland || git clone git@github.com:kevinpita/nixos-hyprland.git ~/nixos-hyprland
   ```

1. If you need to edit secrets, clone `nixos-secrets` and restore the admin key to `~/.config/sops/age/keys.txt` from KeePass. Set mode `0600`.

1. Run `just check` from `~/nixos-config`. Run `just switch` only when you are ready to apply pending changes.

## Self-hosted monitoring

`fium` runs Grafana and Prometheus. All installed NixOS hosts provide node-exporter metrics over Tailscale. See [Self-hosted monitoring](docs/selfhosted.md) for access, credentials, additional targets, and deployment checks.

## Containers

All three hosts use rootless Podman. See [Container use and Docker migration](docs/containers.md) before applying this change to a host with Docker workloads. Docker images and volumes are not moved or deleted automatically.
