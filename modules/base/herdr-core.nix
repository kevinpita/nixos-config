# herdr-core (`hc`) runs the terminals on every host. The herdr app on
# workstations draws them, and reaches the servers' cores over SSH
# (herdr-ssh-client in herdr-remote-host.nix). Over SSH, `hc` alone opens a
# terminal picker.
{
  flake.modules.nixos = {
    base =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.herdr-core ];
      };

    server =
      { username, ... }:
      {
        # hc runs its core as a systemd user service. Without linger, the
        # core and its terminals stop when the last login ends.
        users.users.${username}.linger = true;
      };

    workstation =
      {
        lib,
        pkgs,
        username,
        ...
      }:
      {
        environment.systemPackages = [ pkgs.herdr ];

        home-manager.users.${username} = {
          # Names unnamed tabs after the agent's session title, which omp's
          # smol model writes, or after the running program.
          systemd.user.services.herdr-app-auto-title = {
            Unit = {
              Description = "Name herdr-app tabs after their work";
              PartOf = [ "graphical-session.target" ];
              After = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${lib.getExe pkgs.python3} ${./herdr-app-auto-title.py}";
              Environment = [
                "PATH=${
                  lib.makeBinPath [
                    pkgs.herdr
                    pkgs.herdr-core
                    pkgs.openssh
                  ]
                }"
              ];
              Restart = "on-failure";
              RestartSec = 5;
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };

          xdg.configFile = {
            # Adds omp to the app's "Start an agent" menu. omp is a pi fork, so it
            # uses the shipped pi icon.
            "herdr-app/programs.json".text = builtins.toJSON {
              programs.omp = {
                name = "omp";
                icon = "icons/pi.svg";
                tint = true;
                tile = "#1c1d21";
                color = "#ffffff";
                run = [ "omp" ];
              };
            };

            # Ctrl+B then G opens lazygit in a dialog, like prefix+g in the TUI.
            # The app writes jsconfig.json and .d.ts files into each mod folder,
            # so the folder stays writable and only its files are links.
            "herdr-app/keys.json".source = ./herdr-app/keys.json;
            "herdr-app/mods/lazygit-popup" = {
              source = ./herdr-app/mods/lazygit-popup;
              recursive = true;
            };
          };
        };
      };
  };
}
