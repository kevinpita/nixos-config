{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.hyprland.enable {
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      wofi
      hyprshot
      brightnessctl
      playerctl
    ];
  };
}
