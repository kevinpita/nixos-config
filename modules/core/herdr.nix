{
  pkgs,
  username,
  ...
}:
let
  openDevLayout = pkgs.writeShellApplication {
    name = "herdr-open-dev-layout";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.herdr
      pkgs.jq
    ];
    text = ''
            set -eu

            current_pane_id() {
              herdr pane current | jq -r '.result.pane.pane_id'
            }

            current_workspace_id() {
              herdr pane current | jq -r '.result.pane.workspace_id'
            }

            current_cwd() {
              herdr pane current | jq -r '.result.pane.foreground_cwd // .result.pane.cwd'
            }

            current_tab_id() {
              herdr pane current | jq -r '.result.pane.tab_id'
            }

            workspace_has_named_agent_tab() {
              tab_entries="$(herdr tab list --workspace "$(current_workspace_id)" | jq -r '.result.tabs[] | [.tab_id, .label] | @tsv')"

              while IFS="$(printf '\t')" read -r tab_id tab_label; do
                case "$(printf '%s' "$tab_label" | tr '[:upper:]' '[:lower:]')" in
                  claude|codex)
                    return 0
                    ;;
                esac
              done <<EOF
      $tab_entries
      EOF

              return 1
            }

            run_in_tab() {
              tab_id="$1"
              pane_id="$2"
              label="$3"
              command="$4"

              herdr tab rename "$tab_id" "$label"
              herdr pane run "$pane_id" "$command"
            }

            claude_tab_id="$(current_tab_id)"
            claude_pane_id="$(current_pane_id)"

            if workspace_has_named_agent_tab; then
              exit 0
            fi

            herdr tab rename "$claude_tab_id" claude

            codex_tab_json="$(herdr tab create --workspace "$(current_workspace_id)" --cwd "$(current_cwd)" --label codex --no-focus)"
            zsh_tab_json="$(herdr tab create --workspace "$(current_workspace_id)" --cwd "$(current_cwd)" --label zsh --no-focus)"
            lazygit_tab_json="$(herdr tab create --workspace "$(current_workspace_id)" --cwd "$(current_cwd)" --label lazygit --no-focus)"
            yazi_tab_json="$(herdr tab create --workspace "$(current_workspace_id)" --cwd "$(current_cwd)" --label yazi --no-focus)"

            codex_tab_id="$(printf '%s' "$codex_tab_json" | jq -r '.result.tab.tab_id')"
            codex_pane_id="$(printf '%s' "$codex_tab_json" | jq -r '.result.root_pane.pane_id')"
            zsh_tab_id="$(printf '%s' "$zsh_tab_json" | jq -r '.result.tab.tab_id')"
            zsh_pane_id="$(printf '%s' "$zsh_tab_json" | jq -r '.result.root_pane.pane_id')"
            lazygit_tab_id="$(printf '%s' "$lazygit_tab_json" | jq -r '.result.tab.tab_id')"
            lazygit_pane_id="$(printf '%s' "$lazygit_tab_json" | jq -r '.result.root_pane.pane_id')"
            yazi_tab_id="$(printf '%s' "$yazi_tab_json" | jq -r '.result.tab.tab_id')"
            yazi_pane_id="$(printf '%s' "$yazi_tab_json" | jq -r '.result.root_pane.pane_id')"

            run_in_tab "$claude_tab_id" "$claude_pane_id" claude claude
            run_in_tab "$codex_tab_id" "$codex_pane_id" codex codex
            run_in_tab "$zsh_tab_id" "$zsh_pane_id" zsh clear
            run_in_tab "$lazygit_tab_id" "$lazygit_pane_id" lazygit lazygit
            run_in_tab "$yazi_tab_id" "$yazi_pane_id" yazi yazi
    '';
  };
in
{
  environment.systemPackages = [ pkgs.herdr ];

  home-manager.users.${username} = {
    xdg.configFile."herdr/config.toml" = {
      force = true;
      text = ''
        onboarding = false

        [theme]
        name = "dracula"

        [ui]
        show_agent_labels_on_pane_borders = true
        agent_panel_scope = "all"

        [keys]
        goto = ""

        [[keys.command]]
        key = "prefix+g"
        type = "pane"
        command = "lazygit"

        [[keys.command]]
        key = "prefix+o"
        type = "shell"
        command = "${openDevLayout}/bin/herdr-open-dev-layout"

        [ui.sound]
        enabled = false
      '';
    };

    programs.zsh.shellAliases = {
      hn = "herdr session attach";
      hp = "herdr session attach peersyst";
    };
  };
}
