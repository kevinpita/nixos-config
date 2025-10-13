{
  lib,
  config,
  username,
  ...
}:
lib.mkIf config.gui.enable {
  services = {
    xserver = {
      enable = true;
      xkb.layout = "es";
    };

    displayManager.autoLogin = {
      enable = true;
      user = username;
    };

    libinput.enable = true;
  };
}
