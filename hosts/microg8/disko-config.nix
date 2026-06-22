{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/ata-CT500MX500SSD1_2048E4D32FF5";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # BIOS boot partition
            };
            root = {
              size = "100%";
              content = {
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
                    swap.swapfile.size = "24G";
                  };
                };
              };
            };
          };
        };
      };
      data_a = {
        type = "disk";
        device = "/dev/disk/by-id/ata-MB0500GCEHE_WMAYP7745634";
        content = {
          type = "gpt";
          partitions = {
            data_a_part = {
              size = "100%";
              label = "data_a";
            };
          };
        };
      };
      data_b = {
        type = "disk";
        device = "/dev/disk/by-id/ata-MB0500GCEHE_WMAYP5249710";
        content = {
          type = "gpt";
          partitions = {
            data_b_part = {
              size = "100%";
              label = "data_b";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-d"
                  "raid1"
                  "-m"
                  "raid1"
                  "/dev/disk/by-partlabel/data_a"
                ];
                mountpoint = "/data";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
}
