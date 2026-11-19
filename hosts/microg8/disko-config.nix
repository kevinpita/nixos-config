{
  imports = [
    (import ../disko-btrfs.nix {
      device = "/dev/disk/by-id/ata-CT500MX500SSD1_2048E4D32FF5";
      swapSize = "24G";
      luks = false;
      efi = false;
    })
  ];

  disko.devices.disk = {
    data_a = {
      type = "disk";
      device = "/dev/disk/by-id/ata-MB0500GCEHE_WMAYP7745634";
      content = {
        type = "gpt";
        partitions.data_a_part = {
          size = "100%";
          label = "data_a";
        };
      };
    };
    data_b = {
      type = "disk";
      device = "/dev/disk/by-id/ata-MB0500GCEHE_WMAYP5249710";
      content = {
        type = "gpt";
        partitions.data_b_part = {
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
            mountpoint = "/storage/500gb";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
        };
      };
    };
    storage = {
      type = "disk";
      device = "/dev/disk/by-id/ata-ST1000DM003-1ER162_Z4Y6STVR";
      content = {
        type = "gpt";
        partitions.storage = {
          size = "100%";
          label = "storage_1tb";
          content = {
            type = "btrfs";
            mountpoint = "/storage/1tb";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
        };
      };
    };
  };
}
