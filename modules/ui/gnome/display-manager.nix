{
  flake.modules.nixos.gnome =
    {
      pkgs,
      username,
      ...
    }:
    {
      services = {
        gnome.gcr-ssh-agent.enable = false;
        desktopManager.gnome.enable = true;
        displayManager.gdm.enable = true;
        udev.packages = with pkgs; [ gnome-settings-daemon ];

        xserver.enable = true;

        displayManager.autoLogin = {
          enable = true;
          user = username;
        };
      };
    };
}
