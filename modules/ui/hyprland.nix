{
  flake.modules.nixos.hyprland =
    {
      pkgs,
      username,
      ...
    }:
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };

      services.displayManager = {
        defaultSession = "hyprland";
        autoLogin = {
          enable = true;
          user = username;
        };
        sddm = {
          enable = true;
          wayland.enable = true;
        };
      };

      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      environment.systemPackages = with pkgs; [
        brightnessctl
        cliphist
        grim
        networkmanagerapplet
        pavucontrol
        playerctl
        slurp
        wofi
      ];

      home-manager.users.${username} = {
        services = {
          hyprpolkitagent.enable = true;
          mako = {
            enable = true;
            settings = {
              anchor = "top-right";
              background-color = "#1e1e2e";
              border-color = "#89b4fa";
              border-radius = 10;
              border-size = 2;
              default-timeout = 5000;
              font = "JetBrainsMono Nerd Font 11";
              margin = 12;
              padding = 12;
              text-color = "#cdd6f4";
            };
          };
        };

        programs.waybar = {
          enable = true;
          systemd.enable = true;
          settings.mainBar = {
            layer = "top";
            position = "top";
            height = 34;
            spacing = 4;

            modules-left = [ "hyprland/workspaces" ];
            modules-center = [ "hyprland/window" ];
            modules-right = [
              "tray"
              "network"
              "pulseaudio"
              "backlight"
              "battery"
              "cpu"
              "memory"
              "clock"
            ];

            "hyprland/workspaces" = {
              disable-scroll = true;
              on-click = "activate";
            };
            "hyprland/window" = {
              max-length = 80;
              separate-outputs = true;
            };
            tray.spacing = 8;
            network = {
              "format-wifi" = "󰖩  {essid}";
              "format-ethernet" = "󰈀  {ipaddr}";
              "format-disconnected" = "󰖪";
              "tooltip-format" = "{ifname}: {ipaddr}/{cidr}";
              on-click = "nm-connection-editor";
            };
            pulseaudio = {
              format = "{icon}  {volume}%";
              "format-muted" = "󰖁 muted";
              "format-icons" = {
                default = [
                  ""
                  ""
                  ""
                ];
              };
              on-click = "pavucontrol";
            };
            backlight.format = "󰃠  {percent}%";
            battery = {
              format = "{icon}  {capacity}%";
              "format-charging" = "󰂄  {capacity}%";
              "format-icons" = [
                "󰁺"
                "󰁼"
                "󰁾"
                "󰂀"
                "󰁹"
              ];
            };
            cpu = {
              format = "  {usage}%";
              interval = 2;
            };
            memory = {
              format = "  {}%";
              interval = 2;
            };
            clock = {
              format = "{:%a %d %b  %H:%M}";
              "tooltip-format" = "<tt><small>{calendar}</small></tt>";
            };
          };
          style = ''
            * {
              border: none;
              border-radius: 0;
              font-family: "JetBrainsMono Nerd Font";
              font-size: 13px;
              min-height: 0;
            }

            window#waybar {
              background: rgba(30, 30, 46, 0.94);
              color: #cdd6f4;
            }

            #workspaces button {
              padding: 0 8px;
              color: #a6adc8;
            }

            #workspaces button.active {
              background: #313244;
              color: #89b4fa;
              border-radius: 8px;
            }

            #window,
            #tray,
            #network,
            #pulseaudio,
            #backlight,
            #battery,
            #cpu,
            #memory,
            #clock {
              padding: 0 9px;
            }
          '';
        };

        wayland.windowManager.hyprland = {
          enable = true;
          package = null;
          portalPackage = null;
          configType = "hyprlang";
          systemd.enable = true;

          settings = {
            "$mod" = "SUPER";
            monitor = ",preferred,auto,1";

            exec-once = [
              "nm-applet --indicator"
              "wl-paste --type text --watch cliphist store"
              "wl-paste --type image --watch cliphist store"
            ];

            env = [
              "XCURSOR_SIZE,24"
              "HYPRCURSOR_SIZE,24"
            ];

            input = {
              kb_layout = "es";
              follow_mouse = 1;
              touchpad.natural_scroll = true;
            };

            general = {
              gaps_in = 5;
              gaps_out = 10;
              border_size = 2;
              "col.active_border" = "rgba(89b4faff) rgba(cba6f7ff) 45deg";
              "col.inactive_border" = "rgba(45475aff)";
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

            animations = {
              enabled = true;
              bezier = "easeOutQuint,0.23,1,0.32,1";
              animation = [
                "windows,1,4,easeOutQuint"
                "fade,1,4,default"
                "workspaces,1,4,easeOutQuint,slide"
              ];
            };

            misc = {
              disable_hyprland_logo = false;
              force_default_wallpaper = 0;
            };

            bind = [
              "$mod, RETURN, exec, ghostty"
              "$mod, D, exec, wofi --show drun"
              "$mod, E, exec, ghostty -e yazi"
              "$mod, C, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"
              "$mod, SPACE, exec, grim -g \"$(slurp)\" - | wl-copy"
              "$mod, Q, killactive"
              "$mod, F, fullscreen"
              "$mod, V, togglefloating"
              "$mod SHIFT, E, exit"
              "$mod, left, movefocus, l"
              "$mod, right, movefocus, r"
              "$mod, up, movefocus, u"
              "$mod, down, movefocus, d"
              "$mod SHIFT, left, movewindow, l"
              "$mod SHIFT, right, movewindow, r"
              "$mod SHIFT, up, movewindow, u"
              "$mod SHIFT, down, movewindow, d"
              "$mod, 1, workspace, 1"
              "$mod, 2, workspace, 2"
              "$mod, 3, workspace, 3"
              "$mod, 4, workspace, 4"
              "$mod, 5, workspace, 5"
              "$mod, 6, workspace, 6"
              "$mod, 7, workspace, 7"
              "$mod, 8, workspace, 8"
              "$mod, 9, workspace, 9"
              "$mod SHIFT, 1, movetoworkspace, 1"
              "$mod SHIFT, 2, movetoworkspace, 2"
              "$mod SHIFT, 3, movetoworkspace, 3"
              "$mod SHIFT, 4, movetoworkspace, 4"
              "$mod SHIFT, 5, movetoworkspace, 5"
              "$mod SHIFT, 6, movetoworkspace, 6"
              "$mod SHIFT, 7, movetoworkspace, 7"
              "$mod SHIFT, 8, movetoworkspace, 8"
              "$mod SHIFT, 9, movetoworkspace, 9"
            ];

            bindel = [
              ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
              ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
              ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
              ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
            ];

            bindl = [
              ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
              ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
              ", XF86AudioPlay, exec, playerctl play-pause"
              ", XF86AudioNext, exec, playerctl next"
              ", XF86AudioPrev, exec, playerctl previous"
            ];

            bindm = [
              "$mod, mouse:272, movewindow"
              "$mod, mouse:273, resizewindow"
            ];
          };
        };
      };
    };
}
