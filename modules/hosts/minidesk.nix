{ config, ... }:
{
  flake.modules.nixos."hosts/minidesk" =
    { pkgs, ... }:
    {
      imports = [
        ../../hosts/minidesk/disko-config.nix
        ../../hosts/minidesk/hardware-configuration.nix

        config.flake.modules.nixos.aws
        config.flake.modules.nixos.incus
        config.flake.modules.nixos.kubernetes-client
        config.flake.modules.nixos.server
        config.flake.modules.nixos.work-cloud
        config.flake.modules.nixos.work-github
      ];

      boot.kernelPackages = pkgs.linuxPackages_latest;
    };
}
