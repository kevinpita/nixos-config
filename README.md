# WIP

# NixOS Fresh Installation Guide

## Prerequisites
- [NixOS Minimal ISO](https://nixos.org/download/)
- 64GB USB drive for installation

## Installation Steps

### 1. Create Installation Media
```bash
sudo dd bs=4M conv=fsync oflag=direct status=progress if=<path-to-image> of=/dev/sdX
```

### 2. Prepare USB Drive
```bash
disk=/dev/sdX
sudo sh -c 'echo -e "n\np\n\n\n+32G\nt\n\n82\nw" | fdisk $1 && mkswap $1$(fdisk -l $1 | tail -1 | cut -d" " -f1 | grep -o "[0-9]*$")' -- "$disk"
```

### 3. Initial Setup
```bash
# Boot from USB
sudo su -
loadkeys es
swapon /dev/sdX3
mount -o remount,size=30G,noatime /nix/.rw-store
```

### 4. System Configuration
```bash
nix-shell -p git
git clone https://github.com/kevinpita/nixos-config
cd nixos-config

nix --extra-experimental-features "nix-command flakes" run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake .#HOSTNAME --disk main /dev/ROOT_DISK
```

### 5. User Setup
```bash
passwd root
passwd kevin
```

### 6. Post-Installation Setup (if needed)
```bash
cryptsetup luksOpen /dev/ROOT_DISK cryptroot

mount -o subvol=root /dev/mapper/cryptroot /mnt
mount -o subvol=home /dev/mapper/cryptroot /mnt/home
mount -o subvol=nix /dev/mapper/cryptroot /mnt/nix

nixos-enter

passwd root
passwd kevin
```

### 7. Final Configuration
1. Accept Syncthing request on fium and configure KeePass folder
2. Open KeePass
3. Configure SSH agent
4. Save signing key to sign.pub

```bash
git clone git@github.com:kevinpita/nixos-config.git ~/nixos-config
cd ~/nixos-config
switch
```
