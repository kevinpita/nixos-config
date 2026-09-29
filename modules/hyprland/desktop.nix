{
  flake.modules.nixos.hyprland =
    {
      config,
      hostname,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      cfg = config.programs.nixos-hyprland;
      hostConfig = "hosts/${hostname}/hyprland.lua";
      sessionCommand = "${lib.getExe config.programs.uwsm.package} start -e -D Hyprland hyprland.desktop";
      omasnap = pkgs.stdenv.mkDerivation {
        pname = "omasnap";
        version = "1.19.1";

        src = pkgs.fetchFromGitHub {
          owner = "tobi";
          repo = "omasnap";
          rev = "a07a68d5b73c38166b470196dfeb1afeae75fbb6";
          hash = "sha256-9Dqtevs8TDKcfRuxuDwcNmhcgBThLRh6Qpkl6xTzmw8=";
        };

        nativeBuildInputs = with pkgs; [
          cmake
          ninja
          pkg-config
          qt6.wrapQtAppsHook
          wayland
        ];
        buildInputs = with pkgs; [
          kdePackages.layer-shell-qt
          qt6.qtbase
          wayland
        ];

        postPatch = ''
          substituteInPlace CMakeLists.txt \
            --replace-fail /usr/share/wayland-protocols ${pkgs.wayland-protocols}/share/wayland-protocols
        '';
        cmakeFlags = [ "-DBUILD_TESTING=OFF" ];
        qtWrapperArgs = [
          "--prefix PATH : ${
            lib.makeBinPath [
              config.programs.hyprland.package
              pkgs.tesseract
              pkgs.wl-clipboard
            ]
          }"
        ];

        meta = {
          description = "Native Wayland screenshot and annotation tool for Hyprland";
          homepage = "https://github.com/tobi/omasnap";
          license = lib.licenses.mit;
          mainProgram = "omasnap";
          platforms = lib.platforms.linux;
        };
      };
      sharePicker = pkgs.hyprland-preview-share-picker.overrideAttrs (old: {
        # Window captures are already upright, so rotating them by the monitor transform turns windows on rotated monitors sideways.
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/views/windows.rs \
            --replace-fail "img = img.transform(transform.into());" ""
        '';
      });
      superDoubleTap = pkgs.writeShellApplication {
        name = "super-double-tap";
        runtimeInputs = with pkgs; [
          coreutils
          util-linux
        ];
        text = ''
          runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$UID}"
          state_file="$runtime_dir/super-double-tap"
          now="$(date +%s%3N)"

          exec 9>"$state_file.lock"
          flock 9

          previous=0
          if [[ -r "$state_file" ]]; then
            candidate="$(<"$state_file")"
            if [[ "$candidate" =~ ^[0-9]+$ ]]; then
              previous="$candidate"
            fi
          fi

          if (( now >= previous && now - previous <= 400 )); then
            rm -f "$state_file"
            exec ${lib.getExe config.programs.dms-shell.package} ipc call spotlight toggle
          fi

          printf '%s\n' "$now" > "$state_file"
        '';
      };
      microphoneMute = pkgs.writeShellApplication {
        name = "microphone-mute";
        text = ''
          result="$(${lib.getExe config.programs.dms-shell.package} ipc call audio micmute)"
          case "$result" in
            "Microphone muted") brightness=100 ;;
            "Microphone unmuted") brightness=0 ;;
            *) exit 0 ;;
          esac

          shopt -s nullglob
          for led_path in /sys/class/leds/*::micmute; do
            ${lib.getExe config.programs.dms-shell.package} brightness set \
              "leds:''${led_path##*/}" "$brightness" >/dev/null
          done
        '';
      };
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
      options.programs.nixos-hyprland = {
        configDirectory = lib.mkOption {
          type = lib.types.str;
          default = "${config.programs.nh.flake}/hyprland";
          description = "Absolute path to the writable Hyprland configuration directory";
        };

        hostConfig = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default =
            if builtins.pathExists ../../${hostConfig} then
              "${config.programs.nh.flake}/${hostConfig}"
            else
              null;
          description = "Optional absolute path to host-specific Hyprland Lua configuration";
        };
      };

      config = {
        programs.hyprland = {
          enable = true;
          withUWSM = true;
        };

        services.gvfs.enable = true;

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

        # The upstream Type=idle holds greetd back up to 5 seconds while other
        # boot jobs are still queued, delaying autologin for no benefit.
        systemd.services.greetd.serviceConfig.Type = lib.mkForce "simple";

        programs.dms-shell = {
          enable = true;
          systemd.enable = false;
        };

        home-manager.users.${username} =
          { config, ... }:
          {
            home.pointerCursor = {
              enable = true;
              package = pkgs.adwaita-icon-theme;
              name = "Adwaita";
              size = 24;
            };

            xdg.configFile."hypr/hyprland.lua".text =
              lib.optionalString (cfg.hostConfig != null) ''
                dofile("${cfg.hostConfig}")
              ''
              + ''
                dofile("${cfg.configDirectory}/hyprland.lua")
              '';

            home.packages = with pkgs; [
              inter
              libnotify
              microphoneMute
              nautilus
              nixos-artwork.wallpapers.catppuccin-mocha
              omasnap
              playerctl
              superDoubleTap
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
                # Qt's PipeWire backend asks rtkit for realtime on every sound, flooding the journal.
                Environment = [ "QT_AUDIO_BACKEND=pulseaudio" ];
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
                config.lib.file.mkOutOfStoreSymlink "${cfg.configDirectory}/settings.json";
              "DankMaterialShell/.firstlaunch".text = "";
              "DankMaterialShell/.changelog-1.5".text = "";
              "hypr/xdph.conf".text = ''
                screencopy {
                  allow_token_by_default = true
                  cursor_mode = 2
                  custom_picker_binary = ${lib.getExe sharePicker}
                }
              '';
              "hyprland-preview-share-picker/config.yaml".text = ''
                stylesheets: [style.css]
                default_page: outputs
                hide_token_restore: true
                window:
                  width: 1000
                  height: 560
                image:
                  widget_size: 190
                windows:
                  clicks: 1
                  min_per_row: 4
                  max_per_row: 4
                  spacing: 12
                outputs:
                  clicks: 1
                  spacing: 12
                  show_label: true
                region:
                  command: ${lib.getExe pkgs.slurp} -f '%o@%x,%y,%w,%h'
              '';
              "hyprland-preview-share-picker/style.css".text = ''
                * {
                  font-family: Inter, sans-serif;
                  color: #cdd6f4;
                }
                .window {
                  background: #1e1e2e;
                  border: 1px solid #45475a;
                  border-radius: 16px;
                }
                .window * {
                  background: none;
                  border-color: transparent;
                  box-shadow: none;
                }
                .notebook > header {
                  padding: 12px 12px 0;
                }
                .page {
                  padding: 16px;
                }
                flowboxchild, flowboxchild:focus, .card:focus {
                  outline: none;
                  padding: 0;
                }
                .notebook > header tab {
                  padding: 6px 16px;
                  border-radius: 999px;
                  border: none;
                  box-shadow: none;
                }
                .notebook > header tab:checked {
                  background: #313244;
                }
                .tab-label {
                  font-weight: 600;
                }
                .card {
                  padding: 10px;
                  border-radius: 12px;
                  background: #181825;
                  border: 2px solid transparent;
                  transition: all 120ms ease;
                }
                .card:hover {
                  background: #313244;
                  border-color: #cba6f7;
                }
                .card-loading {
                  opacity: 0.5;
                }
                .image {
                  border-radius: 8px;
                }
                .image-label {
                  margin-top: 8px;
                  font-size: 13px;
                  color: #bac2de;
                }
                .region-button {
                  margin: 24px;
                  padding: 12px 24px;
                  border-radius: 12px;
                  background: #313244;
                  border: none;
                }
                .region-button:hover {
                  background: #45475a;
                }
              '';
            };
          };
      };
    };
}
