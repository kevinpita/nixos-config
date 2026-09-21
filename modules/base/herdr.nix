{
  flake.modules.nixos.base =
    {
      inputs,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      autoTitle = pkgs.callPackage ../../packages/herdr-auto-title/package.nix { };

      startAutoTitle = pkgs.writeShellScript "herdr-start-auto-title" ''
        export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$UID}"
        unit=$(${pkgs.systemd}/bin/systemd-escape --template=herdr-auto-title@.service "$HERDR_SOCKET_PATH")

        # Replace an unmanaged worker only when it belongs to this session.
        if ! ${pkgs.systemd}/bin/systemctl --user is-active --quiet "$unit"; then
          for pid in $(${pkgs.procps}/bin/pgrep -u "$UID" -x herdr-auto-titl); do
            if ${pkgs.gnugrep}/bin/grep -zFxq "HERDR_SOCKET_PATH=$HERDR_SOCKET_PATH" "/proc/$pid/environ" 2>/dev/null; then
              kill "$pid" 2>/dev/null || true
            fi
          done
        fi

        exec ${pkgs.systemd}/bin/systemctl --user restart "$unit"
      '';

      autoTitlePlugin = pkgs.runCommand "herdr-auto-title-plugin" { } ''
        mkdir -p "$out"
        cp ${autoTitle}/herdr-plugin.toml "$out/herdr-plugin.toml"
        ln -s ${startAutoTitle} "$out/herdr-auto-title"
      '';

      herdrWorktrunk = pkgs.fetchFromGitHub {
        owner = "devashish2203";
        repo = "herdr-worktrunk";
        rev = "8ceca541de8fb0d6006727e172534e1e2af17224";
        hash = "sha256-unoP8GUAULiOBTrS/+noCed/VOw6yqBObqHmit17xy0=";
      };

      openFile = pkgs.writeShellApplication {
        name = "open";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          python3
          systemd
          tailscale
          xdg-utils
        ];
        text = ''
          preview_server=${./herdr-open-server.py}
        ''
        + builtins.readFile ./herdr-open.sh;
      };

      openPiTab = pkgs.writeShellApplication {
        name = "herdr-open-pi-tab";
        runtimeInputs = [
          pkgs.herdr
          pkgs.jq
        ];
        text = ''
          set -eu

          IFS=$'\t' read -r workspace_id cwd < <(
            herdr pane current |
              jq -r '[.result.pane.workspace_id, (.result.pane.foreground_cwd // .result.pane.cwd)] | @tsv'
          )

          tab_json="$(herdr tab create --workspace "$workspace_id" --cwd "$cwd" --label pi --focus)"
          pane_id="$(printf '%s' "$tab_json" | jq -r '.result.root_pane.pane_id')"
          herdr pane run "$pane_id" pi
        '';
      };

      openPrWorkspaces = pkgs.writeShellApplication {
        name = "herdr-open-pr-workspaces";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gh
          pkgs.git
          pkgs.gum
          pkgs.herdr
          pkgs.jq
          pkgs.util-linux
          pkgs.worktrunk
        ];
        text = builtins.readFile ./herdr-open-pr-workspaces.sh;
      };
    in
    {
      environment.systemPackages = [
        pkgs.bun
        openFile
      ];

      home-manager.users.${username} = {
        imports = [ inputs.herdr-nix.homeModules.default ];

        xdg.configFile."herdr/plugins/config/worktrunk/config.toml".text = ''
          picker_placement = "popup"
          popup_width = "70%"
          popup_height = 24
        '';

        programs.herdr = {
          enable = true;
          package = pkgs.herdr;
          extraPackages = with pkgs; [
            fzf
            git
            jq
            openssh
            worktrunk
          ];
          plugins = {
            worktrunk = herdrWorktrunk;
            auto-title = autoTitlePlugin;
          };
          settings = {
            theme.name = "dracula";
            ui = {
              show_agent_labels_on_pane_borders = true;
              sound.enabled = false;
            };
            keys = {
              goto = "";
              open_notification_target = "";
              workspace_picker = "";
              command = [
                {
                  key = "prefix+w";
                  type = "plugin_action";
                  command = "worktrunk.open";
                  description = "Worktree: switch / create from default branch";
                }
                {
                  key = "prefix+g";
                  type = "popup";
                  command = "${pkgs.lazygit}/bin/lazygit";
                  description = "open lazygit";
                  width = "80%";
                  height = "80%";
                }
                {
                  key = "prefix+y";
                  type = "popup";
                  command = "${pkgs.yazi}/bin/yazi";
                  description = "open yazi";
                  width = "80%";
                  height = "80%";
                }
                {
                  key = "prefix+o";
                  type = "shell";
                  command = "${openPiTab}/bin/herdr-open-pi-tab";
                  description = "open Pi in a new tab";
                }
                {
                  key = "prefix+alt+p";
                  type = "popup";
                  command = "${openPrWorkspaces}/bin/herdr-open-pr-workspaces";
                  description = "choose and open GitHub PR workspaces";
                  width = "65%";
                  height = "65%";
                }
              ];
            };
          };
        };

        systemd.user.services."herdr-auto-title@" = {
          Unit.Description = "Herdr auto-title for %I";
          Service = {
            ExecStart = "${autoTitle}/bin/herdr-auto-title";
            Environment = [
              "HERDR_SOCKET_PATH=%I"
              "PATH=${lib.makeBinPath [ pkgs.git ]}"
            ];
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        home.activation.reloadHerdrConfig = inputs.home-manager.lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
          if [[ -z "''${DRY_RUN_CMD:-}" ]]; then
            ${pkgs.herdr}/bin/herdr server reload-config >/dev/null 2>&1 || true

            # Herdr does not run plugin startup hooks when config is reloaded.
            while IFS= read -r socket; do
              HERDR_SOCKET_PATH="$socket" ${startAutoTitle}
            done < <(
              ${pkgs.herdr}/bin/herdr session list --json |
                ${pkgs.jq}/bin/jq -r '.sessions[] | select(.running) | .socket_path'
            )
          fi
        '';
      };
    };
}
