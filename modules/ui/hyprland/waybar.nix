{
  flake.modules.nixos.hyprland =
    { username, ... }:
    {
      home-manager.users.${username}.programs.waybar = {
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
    };
}
