# WIP

# NixOS Fresh Installation Guide

## Prerequisites
- [NixOS Minimal ISO](https://nixos.org/download/)
- 64GB USB drive for installation

## Installation Steps

### 1. Set variables
```bash
disk=/dev/sdX
iso=/path/to/image
```

### 2. Create installation media and prepare USB drive
```bash
sudo dd bs=4M conv=fsync oflag=direct status=progress if=$iso of=$disk && \
sudo sh -c '
  echo -e "n\np\n\n\n\nt\n\n82\nw" | fdisk "$1" && \
  blockdev --rereadpt "$1" && \
  mkswap $(fdisk -l "$1" | grep "^/dev" | tail -1 | awk "{print \$1}")
' -- "$disk"lsbl
```

### 3. Initial setup
```bash
# Boot from USB
sudo su -
loadkeys es
swapon /dev/sdX3
mount -o remount,size=30G,noatime /nix/.rw-store
```

### 4. System configuration
```bash
nix-shell -p git
git clone https://github.com/kevinpita/nixos-config
cd nixos-config

nix --extra-experimental-features "nix-command flakes" run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake .#HOSTNAME --disk main /dev/ROOT_DISK
```

### 5. Mount partitions and enter NixOS install
```bash
mount -o subvol=root /dev/mapper/crypted /mnt
mount -o subvol=home /dev/mapper/crypted /mnt/home
mount -o subvol=nix /dev/mapper/crypted /mnt/nix

nixos-enter
```

### 6. User setup
```bash
passwd root
passwd kevin
```

### 7. Final configuration
1. Accept Syncthing request on fium and configure KeePass folder
2. Open KeePass
3. Configure SSH agent
4. Save signing key to sign.pub

```bash
git clone git@github.com:kevinpita/nixos-config.git ~/nixos-config
cd ~/nixos-config
switch
```
