# Shared GPT layout with UEFI or BIOS boot and Btrfs subvolumes for
# root/home/nix plus a swapfile subvolume, optionally wrapped in LUKS.
{
  device,
  swapSize,
  luks ? true,
  efi ? true,
}:
let
  btrfs = {
    type = "btrfs";
    extraArgs = [ "-f" ];
    subvolumes = {
      "/root" = {
        mountpoint = "/";
        mountOptions = [
          "compress=zstd"
          "noatime"
        ];
      };
      "/home" = {
        mountpoint = "/home";
        mountOptions = [
          "compress=zstd"
          "noatime"
        ];
      };
      "/nix" = {
        mountpoint = "/nix";
        mountOptions = [
          "compress=zstd"
          "noatime"
        ];
      };
      "/swap" = {
        mountpoint = "/.swapvol";
        swap.swapfile.size = swapSize;
      };
    };
  };
in
{
  disko.devices.disk.main = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions =
        (
          if efi then
            {
              ESP = {
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "defaults" ];
                };
              };
            }
          else
            {
              bios = {
                size = "1M";
                type = "EF02";
              };
            }
        )
        // (
          if luks then
            {
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "crypted";
                  askPassword = true;
                  settings = {
                    allowDiscards = true;
                  };
                  content = btrfs;
                };
              };
            }
          else
            {
              root = {
                size = "100%";
                content = btrfs;
              };
            }
        );
    };
  };
}
