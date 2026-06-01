{
  config,
  lib,
  username,
  ...
}:
let
  session = "uwsm start hyprland.desktop";
in
lib.mkIf config.features.hyprland.enable {
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = session;
        user = username;
      };
      default_session = {
        command = session;
        user = username;
      };
    };
  };
}
