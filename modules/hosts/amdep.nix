{ config, ... }:
{
  flake.modules.nixos."hosts/amdep" =
    { pkgs, ... }:
    {
      imports = [
        ../../hosts/amdep/disko-config.nix
        ../../hosts/amdep/hardware-configuration.nix

        config.flake.modules.nixos.desktop
        config.flake.modules.nixos.herdr-ssh-client
        config.flake.modules.nixos.qemu
        config.flake.modules.nixos.reverse-engineering
      ];

      fileSystems."/storage/datos" = {
        device = "/dev/disk/by-uuid/8aebe5a1-9a38-40cc-959a-1d2fb65f36e2";
        fsType = "btrfs";
        options = [
          "nofail"
          "noatime"
          "compress=zstd"
        ];
      };

      hardware.bluetooth.enable = true;

      boot.kernelPackages = pkgs.linuxPackages_latest;

      boot.loader.grub.useOSProber = true;
    };
}
