{
  flake.modules.nixos.file-sharing =
    { pkgs, username, ... }:
    {
      home-manager.users.${username}.home.packages = [ pkgs.qbittorrent ];
    };
}
