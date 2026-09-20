# Install or reinstall a host

Run commands from `~/nixos-config` on a machine with Nix flakes and SSH access to the private GitHub inputs. Use the same Bash shell throughout. Replace `<hostname>` and `<ip>` with the target host and installer address.

> [!CAUTION]
> Disko can erase the selected disks. Back up data and the host's age key. To update an installed host instead, use `just switch`.

## 1. Boot the installer

Boot the [NixOS minimal ISO](https://nixos.org/download/), connect to the network, set a root password with `sudo passwd root`, and find the address with `ip a`. Confirm that `ssh root@<ip>` works.

Alternatively, build this repo's ISO with `nix build .#installer-iso`. Its root password is `root`. Change it immediately and use a trusted network.

## 2. Prepare the host

For an unchanged reinstall, reuse the host files and age key. Check that the disk identifiers still match.

For a new host:

1. Copy an existing [host entry point](modules/hosts/) to `modules/hosts/<hostname>.nix`. Set its name to `flake.modules.nixos."hosts/<hostname>"`, update its hardware and disko imports, and select the role and features. Host discovery is automatic.
1. Create `hosts/<hostname>/disko-config.nix` from an existing layout or [`hosts/disko-btrfs.nix`](hosts/disko-btrfs.nix). Use `lsblk -o NAME,SIZE,MODEL,SERIAL` and `ls -l /dev/disk/by-id/` on the target to choose the disk. Check boot mode, encryption, and swap.
1. Set hardware-specific options. For a desktop, add and reference `hosts/<hostname>/hyprland.lua` as existing desktop hosts do.

For new or changed hardware, generate the hardware configuration from the target:

```bash
mkdir -p 'hosts/<hostname>'
ssh root@<ip> 'nixos-generate-config --show-hardware-config --no-filesystems' \
  > 'hosts/<hostname>/hardware-configuration.nix'
```

Check that the command succeeded and review the output. Disko owns the filesystem configuration. When replacing hardware, also review the disk layout and hardware-specific options. Do not run two machines with the same host identity.

## 3. Prepare secrets

Create the directory that will supply the host's age key at installation:

```bash
umask 077
extra_files=$(mktemp -d)
mkdir -p "$extra_files/var/lib/sops-nix"
```

**Existing host:** restore its age key from KeePass to `$extra_files/var/lib/sops-nix/key.txt`, with mode `0600`. If the key and secrets are unchanged, continue to step 4.

**New host:** generate a key, back it up in KeePass, and print its public recipient:

```bash
age-keygen -o "$extra_files/var/lib/sops-nix/key.txt"
age-keygen -y "$extra_files/var/lib/sops-nix/key.txt"
```

In `~/nixos-secrets`:

1. Make sure the admin key is at `~/.config/sops/age/keys.txt`, with mode `0600`.
1. Add the recipient and host rule to `.sops.yaml`. Include it in the rules for `secrets/common.yaml` and any required shared secrets.
1. Create `secrets/<hostname>.yaml` with `sops`. Include `ssh-auth-key`, `ssh-auth-key-pub`, `ssh-sign-key`, `ssh-sign-key-pub`, and any service secrets. Register the public SSH keys with GitHub or other services as needed.
1. Run `sops updatekeys` on existing secret files whose recipients changed. Keep the common `user-password` entry.
1. Commit and push the encrypted files and `.sops.yaml`. Never commit private age keys or plaintext secrets.

If secrets changed, return to `~/nixos-config` and run:

```bash
nix flake update nixos-secrets
```

If an age key was lost, use an authorized admin key to update the recipient and re-encrypt the host and shared secrets before installation.

## 4. Build and commit

Stage new host files so the flake can see them, then format and build without activation:

```bash
git add 'modules/hosts/<hostname>.nix' 'hosts/<hostname>/'
nix fmt
nix build '.#nixosConfigurations.<hostname>.config.system.build.toplevel'
```

Review, commit, and push the host files, lockfile, and related module changes. An unchanged reinstall needs no new commit. Record `git rev-parse HEAD` for the desktop checkout below.

## 5. Optional: register a server with Tailscale

A reinstall loses Tailscale state. To register at first boot, supply a one-use, non-ephemeral auth key:

```bash
mkdir -p "$extra_files/var/lib/tailscale"
(read -rsp 'Tailscale auth key: ' key; echo
 test -n "$key" || exit 1
 umask 077
 printf '%s' "$key" > "$extra_files/var/lib/tailscale/bootstrap-auth-key")
```

Use a pre-approved key if device approval is enabled. Tailnet policy must allow Tailscale SSH. Exit-node approval is separate.

Without this file, automatic registration is skipped. The server deletes it after success and retries failures. Check `journalctl -u tailscaled-autoconnect`. To retry with a new key, replace `/var/lib/tailscale/bootstrap-auth-key` and run `sudo systemctl restart tailscaled-autoconnect`.

## 6. Install

Confirm the target address and disk selection, then run:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$extra_files" \
  --flake '.#<hostname>' --target-host root@<ip>
```

After reboot, check boot, secret decryption, and network access. Encrypted disks need the LUKS passphrase at the console. Once installation succeeds and the age key is backed up, remove the temporary files:

```bash
rm -rf -- "$extra_files"
```

On a desktop, log in as `kevin` at a text console and prepare the checkout before starting the desktop session:

```bash
git clone git@github.com:kevinpita/nixos-config.git ~/nixos-config
cd ~/nixos-config
git checkout <deployed-commit>
```

Use the commit recorded in step 4. No separate Neovim or Hyprland clone is needed. Clone the private input repositories only to edit them.

## Server updates

Servers use [Comin](modules/services/comin.nix) to build and activate `main` with its committed lockfile. Push changes to deploy them. Workstations use `just switch`. Comin does not schedule reboots.

When first enabling Comin on an existing server, commit and push the configuration before running `just switch`. Its SOPS-managed SSH key must read the private inputs without a passphrase or SSH agent. Write access to `main` permits root-level changes on every server.

Check deployments with `systemctl status comin`, `journalctl -u comin -f`, or Grafana's **Monitoring / Comin deployments** dashboard. Metrics travel over Tailscale and show local deployment events, not whether a server matches the latest GitHub commit.
