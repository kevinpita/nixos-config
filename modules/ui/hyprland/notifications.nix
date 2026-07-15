{
  flake.modules.nixos.hyprland =
    {
      username,
      ...
    }:
    {
      home-manager.users.${username} = {
        services.swaync.enable = true;
      };
    };
}
