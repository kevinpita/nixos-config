{
  config,
  lib,
  username,
  ...
}:
lib.mkIf config.features.hyprland.enable {
  home-manager.users.${username} = {
    services.swaync.enable = true;
  };
}
