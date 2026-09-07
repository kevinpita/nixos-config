{ config, ... }:
{
  flake.modules.nixos.server =
    { username, ... }:
    {
      imports = with config.flake.modules.nixos; [
        base
        herdr-remote-host
        mosh
        moshi
        node-exporter
        podman
        tailscale
      ];

      users.users.${username}.linger = true;
    };
}
