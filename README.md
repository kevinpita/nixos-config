# NixOS Configuration

This repository contains my personal NixOS configuration files.

## Installation using nixos-anywhere

This configuration is deployed using `nixos-anywhere`, which remotely installs a NixOS system from this flake.

### 1. Prepare the Target Machine

The installation requires the target machine to be running a basic NixOS environment with an active SSH server. You have two primary ways to achieve this.

#### Option A: From a Live Environment

If the target machine has no OS or you're starting fresh, boot it using the NixOS minimal live ISO. This is the most common method.

1. **Download:** Get the latest [NixOS Minimal ISO](https://nixos.org/download/).
1. **Create a Bootable USB:**
   ```bash
   # Replace /dev/sdX with your USB device
   sudo dd bs=4M conv=fsync oflag=direct status=progress if=/path/to/nixos.iso of=/dev/sdX
   ```
1. **Boot and Prepare:** Boot the target machine from the USB. Once in the live environment, set a password for the `root` user to enable SSH access:
   ```bash
   passwd
   ```
   Then, find the machine's IP address:
   ```bash
   ip a
   ```

#### Option B: From an Existing System

If the target machine already has an operating system with an SSH server, simply ensure you have root access and its IP address.

### 2. Deploy the Configuration

From another computer that has Nix installed, run the `nixos-anywhere` command:

```bash
nix run github:nix-community/nixos-anywhere -- --flake ~/nixos-config#<hostname> root@<ip_address>
```

- Replace `<hostname>` with the desired host from this repository
- Replace `<ip_address>` with the target machine's IP address.

After the script completes, the new system is installed. You can reboot the target machine and log in. The default username is `kevin`, with the password being the same.

## Generating a Hardware Configuration

To generate a hardware configuration for a host during installation, you can use the `--generate-hardware-config` flag with `nixos-anywhere`. This is useful when the existing `hardware-configuration.nix` is invalid or missing.

**Important:** This command will initiate a full NixOS installation on the target machine, not just generate the configuration file.

```bash
nix run github:nix-community/nixos-anywhere -- --flake ~/nixos-config#<hostname> --generate-hardware-config nixos-generate-config ./hosts/<hostname>/hardware-configuration.nix <user>@<ip_address>
```

- Replace `<hostname>` with the name of the host (e.g., `microg8`).
- Replace `<ip_address>` with the target machine's IP address.
- Replace `<user>` with the target machine's ssh user.

This command connects to the target machine, generates the `hardware-configuration.nix` file, places it in the correct host directory within your configuration, and then proceeds with the full NixOS installation.

## Post-Installation Checklist

After logging into the new system, complete the following steps:

1. **Change Passwords:** **IMPORTANT!** Immediately change the default passwords for security.
   ```bash
   # Change your user password
   passwd

   # Change the root password
   sudo passwd root
   ```
1. **Syncthing:** The Syncthing service runs automatically. Access its web UI at `http://localhost:8384` to accept device requests from your other machines and configure the KeePass folder.
1. **KeePass:** Open the application and set up your password database.
1. **SSH Agent:** Configure your SSH agent with your private keys.
1. **Clone Repository:** For future management, clone this repository locally:
   ```bash
   git clone git@github.com:kevinpita/nixos-config.git ~/nixos-config
   cd ~/nixos-config
   ```
1. **Apply Changes:** Run `switch` (a custom alias) to apply any final updates.
