# Multimedia feature - VLC, ffmpeg, Tidal
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.multimedia.enable {
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      ffmpeg
      tidal-hifi
      vlc
    ];
  };
}
