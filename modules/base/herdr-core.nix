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
            # Adds omp to the app's "Start an agent" menu, with the omp logo
            # that herdrAppOmpIcon below copies in.
            "herdr-app/programs.json".text = builtins.toJSON {
              programs.omp = {
                name = "omp";
                icon = "my-icons/omp.svg";
                tint = false;
                tile = "#1c1d21";
                color = "#ffffff";
                run = [ "omp" ];
              };
            };

            # Ctrl+B then Enter opens a terminal in a new tab.
            # Ctrl+B then G opens lazygit in a dialog, like prefix+g in the TUI.
            # Ctrl+B then P opens the branch and PR picker.
            # The app writes jsconfig.json and .d.ts files into each mod folder,
            # so the folder stays writable and only its files are links.
            "herdr-app/keys.json".source = ./herdr-app/keys.json;
            "herdr-app/mods/lazygit-popup" = {
              source = ./herdr-app/mods/lazygit-popup;
              recursive = true;
            };
            # Herdr draws no SVG that is a link into the Nix store, so the mods
            # use the icons that Herdr ships, for example
            # mods/workspace-chrome/git-compare.svg.
            "herdr-app/mods/branch-picker" = {
              source = ./herdr-app/mods/branch-picker;
              recursive = true;
            };
            # A copy of the shipped main layout whose tab bar, tabs-quick, adds
            # omp and branch picker buttons after the last tab. Herdr replaces
            # shipped layouts and mods on start, so the copy has its own names.
            # Click state lives in layouts/.state, so the layout file can be a link.
            "herdr-app/layouts/main-quick.json".source = ./herdr-app/layouts/main-quick.json;
            "herdr-app/mods/tabs-quick" = {
              source = ./herdr-app/mods/tabs-quick;
              recursive = true;
            };
          };

          # Herdr draws no image that is a link or a /nix/store path, so the omp
          # logo (assets/icon.svg from can1357/oh-my-pi) is a copy.
          home.activation.herdrAppOmpIcon = {
            after = [ "linkGeneration" ];
            before = [ ];
            data = ''
              run install -Dm644 ${./herdr-app/omp.svg} "$HOME/.config/herdr-app/my-icons/omp.svg"
            '';
          };
        };
      };
  };
}
