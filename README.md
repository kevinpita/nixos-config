# NixOS Configuration

## Deploy with nixos-anywhere

Secrets (SSH keys, user password) need the host's age key to decrypt. Ship the key during deploy with `--extra-files` so everything works on first boot. The directory structure inside the extra-files dir mirrors the root filesystem.

### New host

All from the deploying machine:

1. Generate an age key for the new host:
   ```bash
   mkdir -p /tmp/extra-files/var/lib/sops-nix
   age-keygen -o /tmp/extra-files/var/lib/sops-nix/key.txt
   chmod 600 /tmp/extra-files/var/lib/sops-nix/key.txt
   age-keygen -y /tmp/extra-files/var/lib/sops-nix/key.txt
   ```
2. Add the public key + creation rule to `~/nixos-secrets/.sops.yaml`
3. Create secrets file: `sops secrets/<hostname>.yaml`
4. Re-encrypt common secrets: `sops updatekeys secrets/common.yaml`
5. Push nixos-secrets, then `nix flake update nixos-secrets` in nixos-config, push
6. Boot target from [NixOS Minimal ISO](https://nixos.org/download/), set root password (`passwd`), get IP (`ip a`)
7. Deploy:
   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --extra-files /tmp/extra-files \
     --flake ~/nixos-config#<hostname> root@<ip>
   ```
8. Save the key (`/tmp/extra-files/var/lib/sops-nix/key.txt`) to KeePass for future reinstalls
9. Clean up: `rm -rf /tmp/extra-files`

### Reinstalling an existing host

All from the deploying machine. No sops changes needed — same key, same encryption.

1. Get the host's age key from KeePass:
   ```bash
   mkdir -p /tmp/extra-files/var/lib/sops-nix
   vim /tmp/extra-files/var/lib/sops-nix/key.txt
   chmod 600 /tmp/extra-files/var/lib/sops-nix/key.txt
   ```
2. Boot target, deploy:
   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --extra-files /tmp/extra-files \
     --flake ~/nixos-config#<hostname> root@<ip>
   ```
3. Clean up: `rm -rf /tmp/extra-files`

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

Everything works on first boot (SSH keys, user password) since the age key was shipped during deploy.

1. Clone repos:
   ```bash
   git clone git@github.com:kevinpita/nixos-config.git ~/nixos-config
   git clone git@github.com:kevinpita/nixos-secrets.git ~/nixos-secrets
   ```
2. Restore admin key to `~/.config/sops/age/keys.txt` (from KeePass, chmod 600)
3. Syncthing: `http://localhost:8384` — accept devices, set up KeePass folder
4. Run `switch` to apply any pending changes
