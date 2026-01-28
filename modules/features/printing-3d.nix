# 3D Printing feature - Prusa Slicer, Super Slicer
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.printing-3d.enable {
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      prusa-slicer
      super-slicer-beta
    ];
  };
}
