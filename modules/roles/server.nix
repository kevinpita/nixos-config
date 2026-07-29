{ config, ... }:
{
  flake.modules.nixos.server =
    { username, ... }:
    {
      imports = with config.flake.modules.nixos; [
        base
        ai
        development
        docker
        git
        syncthing
        tailscale
      ];

      users.users.${username}.linger = true;
    };
}
