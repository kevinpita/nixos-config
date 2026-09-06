import ../disko-btrfs.nix {
  device = "/dev/disk/by-id/ata-SanDisk_SDSSDH3_500G_2105F6451107";
  swapSize = "8G";
  luks = false;
  efi = false;
}
