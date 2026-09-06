{ config, ... }:
{
  flake.modules.nixos.server =
    { username, ... }:
    {
      imports = with config.flake.modules.nixos; [
        ai
        base
        development
        git
        podman
        tailscale
      ];

      users.users.${username}.linger = true;
    };
}
