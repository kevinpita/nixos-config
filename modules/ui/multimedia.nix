{
  flake.modules.nixos.multimedia =
    {
      pkgs,
      username,
      ...
    }:
    {
      home-manager.users.${username} = {
        home.packages = with pkgs; [
          ffmpeg
          obs-studio
          sone # tidal
          vlc
        ];
      };
    };
}
