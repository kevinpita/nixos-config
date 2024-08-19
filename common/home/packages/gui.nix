{ pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    brave

    tidal-hifi

    telegram-desktop

    keepassxc

    jetbrains-mono
  ];
}
