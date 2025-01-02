{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bruno
    keepassxc
    qbittorrent
    telegram-desktop
  ];
}
