{ pkgs, ... }:

{
  home.packages = with pkgs; [
    telegram-desktop
    keepassxc
    qbittorrent
  ];
}
