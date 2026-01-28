# Communication feature - Telegram, Legcord, and other apps
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
      # Communication
      legcord
      telegram-desktop

      # Utilities
      bruno
      keepassxc
      qbittorrent
      arduino-ide
    ];
  };
}
