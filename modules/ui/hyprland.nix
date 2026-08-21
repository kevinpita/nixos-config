{
  flake.modules.nixos.hyprland =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      sessionCommand = "${lib.getExe config.programs.uwsm.package} start -e -D Hyprland hyprland.desktop";
      tuigreetCommand = lib.escapeShellArgs [
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--remember"
        "--asterisks"
        "--cmd"
        sessionCommand
      ];
    in
    {
      programs.hyprland = {
        enable = true;
        withUWSM = true;
      };

      services.greetd = {
        enable = true;
        useTextGreeter = true;
        settings = {
          default_session.command = tuigreetCommand;
          initial_session = {
            command = sessionCommand;
            user = username;
          };
        };
      };

      hardware.bluetooth.enable = true;

      environment.etc."systemd/system-sleep/reset-elan-touchpad" = {
        mode = "0755";
        source = pkgs.writeShellScript "reset-elan-touchpad" ''
          if [ "$1" != post ]; then
            exit 0
          fi

          driver=/sys/bus/i2c/drivers/i2c_hid_acpi
          device=i2c-ELAN0678:00

          if [ ! -e "$driver/$device" ]; then
            exit 0
          fi

          printf '%s' "$device" > "$driver/unbind"
          ${lib.getExe' pkgs.coreutils "sleep"} 0.5
          printf '%s' "$device" > "$driver/bind"
        '';
      };

      services = {
        logind.settings.Login = {
          HandleLidSwitch = "suspend";
          HandleLidSwitchExternalPower = "suspend";
          HandleLidSwitchDocked = "ignore";
        };
        upower.enable = true;
      };
      users.users.${username}.extraGroups = [ "input" ];

      programs.dms-shell = {
        enable = true;
        systemd.enable = false;
        enableSystemMonitoring = false;
        enableVPN = true;
        enableDynamicTheming = true;
        enableAudioWavelength = false;
        enableCalendarEvents = false;
        enableClipboardPaste = true;
      };

      home-manager.users.${username} =
        { config, ... }:
        {
          xdg.configFile."hypr/hyprland.lua".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/config/hypr/hyprland.lua";

          home.packages = with pkgs; [
            grim
            inter
            libnotify
            nixos-artwork.wallpapers.catppuccin-mocha
            playerctl
            slurp
            swappy
          ];

          systemd.user.services.dms = {
            Unit = {
              Description = "Dank Material Shell (DMS)";
              PartOf = [ "graphical-session.target" ];
              After = [ "graphical-session.target" ];
              Requisite = [ "graphical-session.target" ];
            };
            Service = {
              Type = "dbus";
              BusName = "org.freedesktop.Notifications";
              ExecStart = "${lib.getExe pkgs.dms-shell} run --session";
              ExecReload = "${lib.getExe' pkgs.procps "pkill"} -USR1 -x dms";
              Restart = "on-failure";
              RestartSec = "1.23s";
              SuccessExitStatus = "143 SIGTERM";
              TimeoutStopSec = "10s";
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };

          xdg.configFile = {
            "DankMaterialShell/settings.json".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/config/dms/settings.json";
            "DankMaterialShell/.firstlaunch".text = "";
            "DankMaterialShell/.changelog-1.5".text = "";
          };

          home.file.".local/state/DankMaterialShell/session.json".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/config/dms/session.json";
        };
    };
}
