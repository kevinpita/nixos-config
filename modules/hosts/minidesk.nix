{ config, ... }:
{
  flake.modules.nixos."hosts/minidesk" =
    { lib, pkgs, ... }:
    {
      imports = [
        ../../hosts/minidesk/disko-config.nix
        ../../hosts/minidesk/hardware-configuration.nix

        config.flake.modules.nixos.aws
        config.flake.modules.nixos.development
        config.flake.modules.nixos.incus
        config.flake.modules.nixos.kubernetes-client
        config.flake.modules.nixos.server
        config.flake.modules.nixos.work-cloud
        config.flake.modules.nixos.work-github
      ];

      # Rakazo needs Docker API 1.45+ for volume subpaths. Keep Podman running,
      # but let Docker own its CLI name. Clients select the engine by socket.
      virtualisation.podman.dockerCompat = lib.mkForce false;
      virtualisation.docker.rootless.enable = true;

      boot.kernelPackages = pkgs.linuxPackages_latest;
      services.moshi-hook.enable = false;
    };
}
