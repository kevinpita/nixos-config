{
  config,
  lib,
  username,
  ...
}:
lib.mkIf config.features.hyprland.enable {
  home-manager.users.${username} = {
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "tray"
        ];

        "hyprland/workspaces".format = "{id}";
        clock = {
          format = "{:%a %d %b  %H:%M:%S}";
          interval = 1;
        };
        cpu.format = " {usage}%";
        memory.format = " {percentage}%";
        network = {
          format-wifi = " {essid}";
          format-ethernet = " {ifname}";
          format-disconnected = "睊";
        };
        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "婢";
          format-icons.default = [
            ""
            ""
            ""
          ];
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
      };

      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 13px;
        }

        window#waybar {
          background-color: rgba(36, 36, 36, 0.95);
          color: #ffffff;
        }

        #workspaces button {
          padding: 0 8px;
          color: #e3e3e3;
          background: transparent;
        }

        #workspaces button.active {
          color: #ffffff;
          background-color: #3584e4;
          border-radius: 8px;
        }

        #clock,
        #cpu,
        #memory,
        #network,
        #pulseaudio,
        #tray {
          padding: 0 10px;
        }
      '';
    };
  };
}
