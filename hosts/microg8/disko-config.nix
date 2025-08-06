{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sdc";
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
        device = "/dev/sda";
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
        device = "/dev/sdb";
        content = {
          type = "gpt";
          partitions = {
            data_b_part = {
              size = "100%";
              label = "data_b";
            };
          };
        };
      };
    };
    fs = {
      data = {
        type = "btrfs";
        devices = [
          "/dev/disk/by-partlabel/data_a"
          "/dev/disk/by-partlabel/data_b"
        ];
        extraArgs = [
          "-f"
          "-d raid1"
        ];
        mountpoint = "/data";
        mountOptions = [
          "compress=zstd"
          "noatime"
        ];
      };
    };
  };
}
