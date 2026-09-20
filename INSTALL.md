# Install or reinstall a host

Use a deploying machine with Nix flakes enabled, GitHub SSH access to the private inputs, and this repository checked out. Run local commands from `~/nixos-config` in the same Bash shell. Replace `<hostname>` and `<ip>` with the target host name and installer address.

> [!CAUTION]
> This is a full installation, including for an existing device. Disko can erase the selected disks. Back up data and the host's age key first. For a manual configuration update, use `just switch` on the installed host instead.

## Automatic server deployments

The `server` role enables Comin through `modules/services/comin.nix`. It pulls the configuration repository's `main` branch and builds and switches the configuration matching the host name. Push committed changes to deploy them. Comin uses the committed lockfile, rather than updating dependencies itself.

After this module is first added, commit and push it before running `just switch` once on each existing server. This prevents Comin from pulling an older configuration that disables the service. Workstations do not enable Comin.

Comin runs as root for activation. It uses the existing SOPS-managed user SSH key to fetch the private flake inputs, with strict verification against a pinned GitHub host key. The key must have read access to both private repositories without an interactive passphrase or SSH agent. SOPS decryption still uses the host's `/var/lib/sops-nix/key.txt`, and no user login is required.

Use `systemctl status comin` and `journalctl -u comin -f` to inspect deployments. Treat write access to `main` as permission to deploy root-level changes to every server. This setup does not schedule reboots.

## 1. Boot the target and choose the host

Boot the target with the [NixOS minimal ISO](https://nixos.org/download/). Connect it to the network, run `sudo passwd root`, and find its address with `ip a`. Confirm that `ssh root@<ip>` works from the deploying machine.

You can also build this repository's ISO with `nix build .#installer-iso`. Its root password is `root`. Use it only on a trusted network and change the password immediately.

| Situation | What to reuse or change |
| --- | --- |
| Reinstall the same device | Reuse its host module, hardware configuration, disk layout, and backed-up age key. Verify the disk identifiers before installation. |
| Replace hardware under an existing host name | Reuse the host identity and age key, but regenerate the hardware configuration and review the disk layout and hardware-specific settings. Do not keep the old machine active with the same identity. |
| Add another device | Choose a unique host name, create its module and disk layout, generate its hardware configuration, and add new host secrets. |

## 2. Prepare the configuration

Skip file creation for an unchanged device. For a new host:

1. Create `modules/hosts/<hostname>.nix`, using an existing [host entry point](modules/hosts/) as a reference. Define `flake.modules.nixos."hosts/<hostname>"`, import its hardware and disko files from `../../hosts/<hostname>/`, and select a role such as `config.flake.modules.nixos.desktop` or `config.flake.modules.nixos.server`. Hosts are discovered automatically. Do not add imports to `flake.nix`.
1. Create `hosts/<hostname>/disko-config.nix`. Adapt an existing layout or use [`hosts/disko-btrfs.nix`](hosts/disko-btrfs.nix). Check the target's disks with `lsblk -o NAME,SIZE,MODEL,SERIAL` and `ls -l /dev/disk/by-id/`. Set the correct device, boot mode, encryption, and swap size. Do not copy another machine's disk identifier.
1. Set any host-specific networking, CPU/GPU, laptop, and desktop settings. For a desktop, add and reference its `hosts/<hostname>/hyprland.lua` as the existing desktop hosts do.

For new or changed hardware, generate the hardware file **from the target**, on the deploying machine:

```bash
mkdir -p 'hosts/<hostname>'
ssh root@<ip> 'nixos-generate-config --show-hardware-config --no-filesystems' \
  > 'hosts/<hostname>/hardware-configuration.nix'
```

Confirm the command succeeded and review the generated file. `--no-filesystems` leaves storage configuration to disko. This only scans hardware, it does not install or format anything. Generate it before deployment so you can review and commit the result.

## 3. Prepare the age key and secrets

The installed system needs `/var/lib/sops-nix/key.txt` to decrypt its credentials on first boot:

```bash
umask 077
extra_files=$(mktemp -d)
mkdir -p "$extra_files/var/lib/sops-nix"
```

**Existing host identity:** restore its age key from KeePass to `$extra_files/var/lib/sops-nix/key.txt` and set its mode to `0600`. No secret changes are needed if the same key and host name are reused.

**New host identity:** generate and back up a new key in KeePass:

```bash
age-keygen -o "$extra_files/var/lib/sops-nix/key.txt"
age-keygen -y "$extra_files/var/lib/sops-nix/key.txt"
```

Then, in `~/nixos-secrets`:

1. Restore the admin key to `~/.config/sops/age/keys.txt` with mode `0600` if needed.
1. Add the new public age recipient and host creation rule to `.sops.yaml`. Include the recipient in the rule for `secrets/common.yaml` and any shared secrets the selected services need.
1. Create `secrets/<hostname>.yaml` with `sops`. The base configuration requires `ssh-auth-key`, `ssh-auth-key-pub`, `ssh-sign-key`, and `ssh-sign-key-pub`. Add any secrets required by the selected services. Register the new SSH public keys with GitHub or other services as needed.
1. Run `sops updatekeys secrets/common.yaml` and repeat for any other existing secret files whose recipients changed. Keep the common `user-password` entry.
1. Review, **commit, and push** `.sops.yaml` and the encrypted secret files. Never commit private age keys or plaintext secrets.

Back in `~/nixos-config`, fetch the published secret revision:

```bash
nix flake update nixos-secrets
```

Skip this update if the secrets did not change. If you replace a lost age key, update the host's recipient and re-encrypt its host and shared secret files with an authorized admin key before deployment.

## 4. Review and commit the configuration

Add new host files to Git so that the flake can see them, then format and build the target without activation:

```bash
git add 'modules/hosts/<hostname>.nix' 'hosts/<hostname>/'
nix fmt
nix build '.#nixosConfigurations.<hostname>.config.system.build.toplevel'
```

Review the host files and `flake.lock`, stage the intended changes, then **commit and push** them. Include any related module changes. Do not commit the extra-files directory. For an unchanged reinstall, no new commit is needed.

Record `git rev-parse HEAD` so that the target's desktop checkout can use the deployed revision.

## 5. Optionally prepare Tailscale for a server

A fresh installation does not retain the old Tailscale state, even if it reuses the age key. For first-boot registration, add a one-use, non-ephemeral auth key:

```bash
mkdir -p "$extra_files/var/lib/tailscale"
(read -rsp 'Tailscale auth key: ' key; echo
 test -n "$key" || exit 1
 umask 077
 printf '%s' "$key" > "$extra_files/var/lib/tailscale/bootstrap-auth-key")
```

Use a pre-approved key if device approval is enabled. Tailnet policy must permit Tailscale SSH. Exit-node approval is separate.

Without this file, automatic registration is skipped. The server deletes the file after successful registration and retries failures. Inspect failures with `journalctl -u tailscaled-autoconnect`. To retry later, provide a fresh key at `/var/lib/tailscale/bootstrap-auth-key` and run `sudo systemctl restart tailscaled-autoconnect`.

## 6. Deploy and finish

Check the target address and disk selection once more, then run:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$extra_files" \
  --flake '.#<hostname>' --target-host root@<ip>
```

After reboot, confirm that the installed system boots, secrets decrypt, and network access works. For encrypted disks, be ready to enter the LUKS passphrase at the console. After successful installation and key backup, remove the local temporary files with `rm -rf -- "$extra_files"`.

On a desktop, log in as `kevin` at a text console before starting the desktop session:

```bash
git clone git@github.com:kevinpita/nixos-config.git ~/nixos-config
cd ~/nixos-config
git checkout <deployed-commit>
```

Use the commit recorded in step 4. No separate Neovim or Hyprland clone is needed. Clone `~/nixos-pi`, `~/nixos-secrets`, or `~/nixos-work` only if you need to edit those repositories.
