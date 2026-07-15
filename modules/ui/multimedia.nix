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
          obsidian
          sone # tidal
          vlc
        ];
      };
    };
}
