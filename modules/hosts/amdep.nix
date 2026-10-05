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

      hardware.bluetooth.enable = true;

      boot.kernelPackages = pkgs.linuxPackages_latest;

      boot.loader.grub.useOSProber = true;
    };
}
