# NixOS Configuration

## Check and format

Use the real private inputs when working locally:

```bash
nix flake check --all-systems
```

Use the committed dummy input to reproduce public CI:

```bash
nix flake check --all-systems --show-trace \
  --override-input nixos-secrets path:./ci-dummy-input \
  --override-input nixos-work path:./ci-dummy-input
```

Format with:

```bash
nix fmt
```

Apply the current host with:

```bash
nh os switch ~/nixos-config
```

## Hosts

Hosts are declared in `nixos-configurations.nix`. Add a host there before deploying it with `--flake ~/nixos-config#<hostname>`.

| Host | Type | Notes |
| ------- | ------------------- | ------------------------------------------- |
| amdep | Workstation | Full desktop, dual-boot |
| hulk | Server | k3s single-node, Kubernetes tools |
| microg8 | Server | BIOS boot, drive monitor |
| t14g6 | ThinkPad laptop | Full desktop, TLP, nixos-hardware module |
| t480s | ThinkPad laptop | Full desktop, TLP, dual-boot, nixos-hardware module |

## Deploy with nixos-anywhere

Secrets (SSH keys, user password) need the host's age key to decrypt. Ship the key during deploy with `--extra-files` so everything works on first boot. The directory structure inside the extra-files dir mirrors the root filesystem.

### New host or first install

First add `hosts/<hostname>`, wire it in `nixos-configurations.nix`, and add the matching secret files. Then run the install from the deploying machine:

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

On hosts with `features.sops-admin.enable = true`, the admin age key is managed by sops at `~/.config/sops/age/keys.txt` after the system has enough secret access to switch successfully.

## Post-install checklist

Everything works on first boot (SSH keys, user password) since the age key was shipped during deploy.

1. Clone repos:
   ```bash
   git clone git@github.com:kevinpita/nixos-config.git ~/nixos-config
   git clone git@github.com:kevinpita/nixos-secrets.git ~/nixos-secrets
   ```
1. Restore admin key to `~/.config/sops/age/keys.txt` from KeePass if this host does not manage it through `features.sops-admin.enable`
1. Syncthing: `http://localhost:8384`, accept devices and set up KeePass folder
1. Run `nh os switch ~/nixos-config` to apply any pending changes
