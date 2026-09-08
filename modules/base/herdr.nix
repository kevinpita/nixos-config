{
  flake.modules.nixos.base =
    {
      inputs,
      pkgs,
      username,
      ...
    }:
    let
      herdrWorktrunk = pkgs.fetchFromGitHub {
        owner = "devashish2203";
        repo = "herdr-worktrunk";
        rev = "a3107ca566bafcd463bc138007a0c01051970784";
        hash = "sha256-+G4EzlQisIr8SQ1NwDfzV/27iOiC3r/2nkxjcV/aU/k=";
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
      environment.systemPackages = [ pkgs.bun ];

      home-manager.users.${username} = {
        imports = [ inputs.herdr-nix.homeModules.default ];

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
            auto-title = pkgs.callPackage ../../packages/herdr-auto-title/package.nix { };
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
              command = [
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

        home.activation.reloadHerdrConfig =
          inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ]
            ''
              if [[ -z "''${DRY_RUN_CMD:-}" ]]; then
                ${pkgs.herdr}/bin/herdr server reload-config >/dev/null 2>&1 || true
              fi
            '';
      };
    };
}
