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

      environment.etc."crypttab".text = ''
        datos /dev/disk/by-id/ata-ST2000DM008-2FR102_WFL3CGKJ-part1 none luks,nofail,x-systemd.device-timeout=15s
      '';

      fileSystems."/storage/datos" = {
        device = "/dev/mapper/datos";
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

      # A short press of the case power button does nothing. A long press
      # still cuts the power in firmware.
      services.logind.settings.Login.HandlePowerKey = "ignore";
    };
}
