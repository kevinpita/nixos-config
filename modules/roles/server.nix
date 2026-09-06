{ config, ... }:
{
  flake.modules.nixos.server =
    { username, ... }:
    {
      imports = with config.flake.modules.nixos; [
        base
        ai
        development
        podman
        git
        tailscale
      ];

      users.users.${username}.linger = true;
    };
}
