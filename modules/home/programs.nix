{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bruno
    keepassxc
    legcord
    qbittorrent
    telegram-desktop
    arduino-ide
  ];
}
