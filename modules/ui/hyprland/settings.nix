{
  flake.modules.nixos.hyprland =
    {
      lib,
      username,
      ...
    }:
    let
      lua = lib.generators.mkLuaInline;
    in
    {
      home-manager.users.${username}.wayland.windowManager.hyprland = {
        enable = true;
        package = null;
        portalPackage = null;
        configType = "lua";
        systemd.enable = true;

        settings = {
          mod._var = "SUPER";

          monitor = {
            output = "";
            mode = "preferred";
            position = "auto";
            scale = 1;
          };

          on = {
            _args = [
              "hyprland.start"
              (lua ''
                function()
                  hl.exec_cmd("nm-applet --indicator")
                  hl.exec_cmd("wl-paste --type text --watch cliphist store")
                  hl.exec_cmd("wl-paste --type image --watch cliphist store")
                end
              '')
            ];
          };

          env = [
            {
              _args = [
                "XCURSOR_SIZE"
                "24"
              ];
            }
            {
              _args = [
                "HYPRCURSOR_SIZE"
                "24"
              ];
            }
          ];

          config = {
            input = {
              kb_layout = "es";
              follow_mouse = 1;
              touchpad.natural_scroll = true;
            };

            general = {
              gaps_in = 5;
              gaps_out = 10;
              border_size = 2;
              col = {
                active_border = {
                  colors = [
                    "rgba(89b4faff)"
                    "rgba(cba6f7ff)"
                  ];
                  angle = 45;
                };
                inactive_border = "rgba(45475aff)";
              };
              layout = "dwindle";
              resize_on_border = true;
            };

            decoration = {
              rounding = 10;
              active_opacity = 1.0;
              inactive_opacity = 0.96;
              blur = {
                enabled = true;
                size = 6;
                passes = 2;
              };
              shadow = {
                enabled = true;
                range = 12;
                render_power = 3;
                color = "rgba(11111b99)";
              };
            };

            animations.enabled = true;

            misc = {
              disable_hyprland_logo = false;
              force_default_wallpaper = 0;
            };
          };

          curve = {
            _args = [
              "easeOutQuint"
              {
                type = "bezier";
                points = [
                  [
                    0.23
                    1
                  ]
                  [
                    0.32
                    1
                  ]
                ];
              }
            ];
          };

          animation = [
            {
              leaf = "windows";
              enabled = true;
              speed = 4;
              bezier = "easeOutQuint";
            }
            {
              leaf = "fade";
              enabled = true;
              speed = 4;
              bezier = "default";
            }
            {
              leaf = "workspaces";
              enabled = true;
              speed = 4;
              bezier = "easeOutQuint";
              style = "slide";
            }
          ];
        };
      };
    };
}
