{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.communication.enable {
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      legcord
      telegram-desktop

      bruno
      keepassxc
      qbittorrent
      arduino-ide
    ];
  };
}
