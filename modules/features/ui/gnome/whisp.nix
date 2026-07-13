{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.gnome.enable {
  home-manager.users.${username} = {
    home.packages = [ pkgs.whisp ];
  };
}
