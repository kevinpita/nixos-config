{ config, ... }:
{
  flake.modules.nixos.server =
    { ... }:
    {
      imports = with config.flake.modules.nixos; [
        base
        herdr-remote-host
        mosh
        node-exporter
        podman
        tailscale
      ];

      host.roles = [ "server" ];
    };
}
