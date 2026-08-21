import ../disko-btrfs.nix {
  device = "/dev/nvme0n1";
  swapSize = "8G";
  luks = false;
}
