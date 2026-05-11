{
  config,
  lib,
  pkgs,
  username,
  hostname,
  ...
}:
let
  ssh-split-src = pkgs.fetchFromGitHub {
    owner = "pschmitt";
    repo = "tmux-ssh-split";
    rev = "master";
    sha256 = "12ahwz6f76b0q1zqpi6ha6043lb6wzpq24v8m96cb2mdmnihkzxz";
  };

  ssh-split = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "ssh-split";
    version = "unstable-2024-05-18";
    src = pkgs.stdenv.mkDerivation {
      name = "ssh-split-patched";
      src = ssh-split-src;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      installPhase = ''
        mkdir -p $out/scripts
        cp ssh-split.tmux $out/
        cp scripts/tmux-ssh-split.sh $out/scripts/
        patchShebangs $out/scripts/tmux-ssh-split.sh
        wrapProgram $out/scripts/tmux-ssh-split.sh \
          --prefix PATH : ${
            lib.makeBinPath (
              with pkgs;
              [
                bash
                coreutils
                procps
                gnugrep
                gnused
                gawk
                openssh
              ]
            )
          }
      '';
    };
  };
in
lib.mkIf config.features.development.enable {
  environment.systemPackages = with pkgs; [
    go
    gotest
    python3

    lazydocker
    lazysql
    mqttui
  ];

  home-manager.users.${username} = {
    home.packages = with pkgs; [
      nixd
      nixfmt

      jetbrains.datagrip
      jetbrains.goland
      jetbrains.idea
    ];

    programs = {
      tmux = {
        enable = true;
        terminal = "tmux-256color";
        mouse = true;
        shortcut = "a";
        baseIndex = 1;
        escapeTime = 0;
        historyLimit = 50000;
        extraConfig = ''
          # ssh-split configuration
          set-option -g @ssh-split-keep-cwd "true"
          set-option -g @ssh-split-keep-remote-cwd "true"
          set-option -g @ssh-split-strip-cmd "true"

          # Manual bindings to the patched script
          bind | run-shell "${ssh-split.src}/scripts/tmux-ssh-split.sh -h"
          bind - run-shell "${ssh-split.src}/scripts/tmux-ssh-split.sh -v"

          # Vi-style pane navigation
          bind h select-pane -L
          bind j select-pane -D
          bind k select-pane -U
          bind l select-pane -R

          # Resizing panes
          bind -r H resize-pane -L 5
          bind -r J resize-pane -D 5
          bind -r K resize-pane -U 5
          bind -r L resize-pane -R 5
        '';
        plugins = with pkgs.tmuxPlugins; [
          sensible
          yank
          resurrect
          {
            plugin = continuum;
            extraConfig = ''
              set -g @continuum-restore 'on'
              set -g @continuum-save-interval '15'
            '';
          }
          {
            plugin = catppuccin;
            extraConfig = ''
              set -g @catppuccin_flavor 'mocha'
              set -g @catppuccin_window_tabs_enabled on
              set -g @catppuccin_status_modules_right "application session user host date_time"
            '';
          }
          {
            plugin = tmux-which-key;
          }
          ssh-split
        ];
      };

      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      vscodium = {
        enable = true;
        profiles.default = {
          extensions = with pkgs.vscode-marketplace; [
            eliverlara.andromeda
            github.vscode-github-actions
            golang.go
            jakebecker.elixir-ls
            jnoortheen.nix-ide
            tim-koehler.helm-intellisense
            vscodevim.vim
          ];

          userSettings = {
            "telemetry.telemetryLevel" = "off";

            "editor.fontSize" = 18;
            "editor.fontFamily" = "'Jetbrains Mono', 'monospace', monospace";
            "workbench.colorTheme" = "Andromeda";

            "files.autoSave" = "afterDelay";
            "editor.formatOnSave" = true;
            "[nix]" = {
              "editor.defaultFormatter" = "jnoortheen.nix-ide";
            };

            "nix.enableLanguageServer" = true;
            "nix.serverPath" = "nixd";
            "nix.serverSettings" = {
              "nixd" = {
                "formatting" = {
                  "command" = [ "nixfmt" ];
                };
                "options" = {
                  "home-manager" = {
                    "expr" =
                      "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.${hostname}.options.home-manager.users.type.getSubOptions []";
                  };
                };
              };
            };

            "vim.normalModeKeyBindingsNonRecursive" = [
              {
                before = [
                  ":"
                  "w"
                ];
                commands = [ "workbench.action.files.save" ];
              }
            ];
          };
        };
      };
    };
  };
}
