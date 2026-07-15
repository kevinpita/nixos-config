{
  flake.modules.nixos.hyprland =
    {
      pkgs,
      username,
      ...
    }:
    let
      # Self-contained solid dark wallpaper so hyprpaper always has a valid image.
      wallpaper = pkgs.runCommand "hypr-wallpaper.png" { } ''
        ${pkgs.imagemagick}/bin/magick -size 2560x1440 xc:'#242424' $out
      '';
    in
    {
      home-manager.users.${username} = {
        services.hyprpaper = {
          enable = true;
          settings = {
            preload = [ "${wallpaper}" ];
            wallpaper = [ ",${wallpaper}" ];
          };
        };

        programs.hyprlock = {
          enable = true;
          settings = {
            background = {
              color = "rgba(36, 36, 36, 1.0)";
            };
            input-field = {
              size = "300, 50";
              outline_thickness = 2;
              outer_color = "rgba(53, 132, 228, 1.0)";
              inner_color = "rgba(47, 47, 47, 1.0)";
              font_color = "rgba(255, 255, 255, 1.0)";
            };
          };
        };

        services.hypridle = {
          enable = true;
          settings = {
            general = {
              lock_cmd = "pidof hyprlock || hyprlock";
              before_sleep_cmd = "loginctl lock-session";
              after_sleep_cmd = "hyprctl dispatch dpms on";
            };
            listener = [
              {
                timeout = 300;
                on-timeout = "loginctl lock-session";
              }
              {
                timeout = 330;
                on-timeout = "hyprctl dispatch dpms off";
                on-resume = "hyprctl dispatch dpms on";
              }
            ];
          };
        };
      };
    };
}
