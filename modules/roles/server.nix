{ config, ... }:
{
  flake.modules.nixos.server =
    { pkgs, ... }:
    {
      imports = with config.flake.modules.nixos; [
        base
        herdr-remote-host
        mosh
        node-exporter
        podman
        tailscale
      ];

      environment.systemPackages = [ pkgs.forklab ];

      host.roles = [ "server" ];
    };
}
