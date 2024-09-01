{ pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    brave

    tidal-hifi

    telegram-desktop

    keepassxc

    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];
}
