{
  config,
  lib,
  username,
  ...
}:
{
  imports = [
    ./login.nix
    ./keybinds.nix
    ./waybar.nix
    ./notifications.nix
    ./theming.nix
    ./packages.nix
  ];

  config = lib.mkIf config.features.hyprland.enable {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    home-manager.users.${username} = {
      wayland.windowManager.hyprland = {
        enable = true;
        # Use the system Hyprland from programs.hyprland instead of HM's own.
        package = null;
        portalPackage = null;
        # uwsm manages the session, so HM should not own the systemd target.
        systemd.enable = false;

        settings = {
          monitor = lib.mkDefault ",preferred,auto,auto";

          "$mod" = "SUPER";

          input = {
            kb_layout = "es";
            follow_mouse = 1;
            touchpad.natural_scroll = true;
          };

          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            "col.active_border" = "rgba(3584e4ee)";
            "col.inactive_border" = "rgba(1b1b1baa)";
            layout = "dwindle";
          };

          decoration = {
            rounding = 10;
            blur = {
              enabled = true;
              size = 6;
              passes = 2;
            };
          };

          animations.enabled = true;

          dwindle = {
            pseudotile = true;
            preserve_split = true;
          };
        };
      };
    };
  };
}
