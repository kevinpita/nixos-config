{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.browsers.enable {
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      brave
      chromium
      firefox
    ];
  };
}
