{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ffmpeg
    tidal-hifi
    vlc
  ];
}
