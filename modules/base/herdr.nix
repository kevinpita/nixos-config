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
      environment.systemPackages = [
        pkgs.bun
        pkgs.herdr
      ];

      home-manager.users.${username} = {
        xdg.configFile."herdr/config.toml" = {
          force = true;
          text = ''
            onboarding = false

            [theme]
            name = "dracula"

            [ui]
            show_agent_labels_on_pane_borders = true

            [keys]
            goto = ""

            [[keys.command]]
            key = "prefix+g"
            type = "popup"
            command = "lazygit"
            description = "open lazygit"
            width = "80%"
            height = "80%"

            [[keys.command]]
            key = "prefix+y"
            type = "popup"
            command = "yazi"
            description = "open yazi"
            width = "80%"
            height = "80%"

            [[keys.command]]
            key = "prefix+o"
            type = "shell"
            command = "${openPiTab}/bin/herdr-open-pi-tab"
            description = "open Pi in a new tab"

            [[keys.command]]
            key = "prefix+alt+p"
            type = "popup"
            command = "${openPrWorkspaces}/bin/herdr-open-pr-workspaces"
            description = "choose and open GitHub PR workspaces"
            width = "65%"
            height = "65%"

            [ui.sound]
            enabled = false
          '';
        };

        home.activation.installHerdrWorktrunk =
          inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ]
            ''
              if [[ -z "''${DRY_RUN_CMD:-}" ]]; then
                plugin_json="$(${pkgs.herdr}/bin/herdr plugin list --plugin worktrunk --json 2>/dev/null || true)"
                plugin_root="$(printf '%s' "$plugin_json" | ${pkgs.jq}/bin/jq -r '.result.plugins[0].plugin_root // empty' 2>/dev/null || true)"

                if [[ "$plugin_root" != "${herdrWorktrunk}" ]]; then
                  if [[ -n "$plugin_root" ]]; then
                    plugin_kind="$(printf '%s' "$plugin_json" | ${pkgs.jq}/bin/jq -r '.result.plugins[0].source.kind // empty')"

                    if [[ "$plugin_kind" == "local" ]]; then
                      ${pkgs.herdr}/bin/herdr plugin unlink worktrunk >/dev/null
                    else
                      ${pkgs.herdr}/bin/herdr plugin uninstall worktrunk >/dev/null
                    fi
                  fi

                  ${pkgs.herdr}/bin/herdr plugin link "${herdrWorktrunk}" >/dev/null
                fi

                ${pkgs.herdr}/bin/herdr server reload-config >/dev/null 2>&1 || true
              fi
            '';
      };
    };
}
