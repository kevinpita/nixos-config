{ pkgs, ... }:

{
  imports = [
    ../programs/gnome.nix
    ../programs/alacritty.nix
  ];
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    firefox
    brave

    tidal-hifi

    telegram-desktop

    keepassxc

    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];
}
