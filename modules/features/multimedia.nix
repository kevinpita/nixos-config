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
      obs-studio
      tidal-hifi
      vlc
    ];
  };
}
